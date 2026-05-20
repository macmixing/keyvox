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

### llama.cpp / ggml (binary XCFramework)
- Upstream: <https://github.com/ggml-org/llama.cpp>
- License: MIT
- Note: bundled through `Packages/KeyVoxLocalInference` for local Vibes rewrite inference. The vendored XCFramework is sourced from the official llama.cpp `b9093` Apple release artifact and includes the Metal backend used by Mac Vibes GPU offload.

Copyright (c) Georgi Gerganov and the llama.cpp contributors

### Qwen2.5-0.5B-Instruct (downloaded model artifact)
- Upstream model: <https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct>
- GGUF distribution: <https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF>
- License: Apache License 2.0
- License URL: <https://www.apache.org/licenses/LICENSE-2.0>
- Note: KeyVox downloads the `qwen2.5-0.5b-instruct-q4_k_m.gguf` artifact at runtime for local Vibes rewrite inference.

Attribution: Based on Alibaba Cloud's `Qwen2.5-0.5B-Instruct` model.

### KeyVox Vibes LoRA adapters (bundled model adapter artifacts)
- Bundled package: `Packages/KeyVoxVibesAdapters`
- Bundled files:
  - `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/polished-alpha-025-lora.gguf`
  - `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/casual-alpha-5-lora.gguf`
- Compatible base model: `Qwen2.5-0.5B-Instruct`
- Upstream base model: <https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct>
- Base model license: Apache License 2.0
- Note: These are KeyVox-trained LoRA adapter artifacts for local Vibes rewrite behavior. They are product-specific model adapter assets bundled with the app and are not part of the repository's MIT-licensed source code.

### MIT License (applies to `whisper.cpp`, OpenAI Whisper, and `llama.cpp` above)

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

### Apache License 2.0 (applies to Qwen model artifacts above)

Apache License
Version 2.0, January 2004
<http://www.apache.org/licenses/>

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

"License" shall mean the terms and conditions for use, reproduction, and
distribution as defined by Sections 1 through 9 of this document.

"Licensor" shall mean the copyright owner or entity authorized by the copyright
owner that is granting the License.

"Legal Entity" shall mean the union of the acting entity and all other entities
that control, are controlled by, or are under common control with that entity.
For the purposes of this definition, "control" means (i) the power, direct or
indirect, to cause the direction or management of such entity, whether by
contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the
outstanding shares, or (iii) beneficial ownership of such entity.

"You" (or "Your") shall mean an individual or Legal Entity exercising
permissions granted by this License.

"Source" form shall mean the preferred form for making modifications, including
but not limited to software source code, documentation source, and configuration
files.

"Object" form shall mean any form resulting from mechanical transformation or
translation of a Source form, including but not limited to compiled object code,
generated documentation, and conversions to other media types.

"Work" shall mean the work of authorship, whether in Source or Object form,
made available under the License, as indicated by a copyright notice that is
included in or attached to the work.

"Derivative Works" shall mean any work, whether in Source or Object form, that
is based on (or derived from) the Work and for which the editorial revisions,
annotations, elaborations, or other modifications represent, as a whole, an
original work of authorship. For the purposes of this License, Derivative Works
shall not include works that remain separable from, or merely link (or bind by
name) to the interfaces of, the Work and Derivative Works thereof.

"Contribution" shall mean any work of authorship, including the original version
of the Work and any modifications or additions to that Work or Derivative Works
thereof, that is intentionally submitted to Licensor for inclusion in the Work
by the copyright owner or by an individual or Legal Entity authorized to submit
on behalf of the copyright owner.

"Contributor" shall mean Licensor and any individual or Legal Entity on behalf
of whom a Contribution has been received by Licensor and subsequently
incorporated within the Work.

2. Grant of Copyright License. Subject to the terms and conditions of this
License, each Contributor hereby grants to You a perpetual, worldwide,
non-exclusive, no-charge, royalty-free, irrevocable copyright license to
reproduce, prepare Derivative Works of, publicly display, publicly perform,
sublicense, and distribute the Work and such Derivative Works in Source or
Object form.

3. Grant of Patent License. Subject to the terms and conditions of this License,
each Contributor hereby grants to You a perpetual, worldwide, non-exclusive,
no-charge, royalty-free, irrevocable patent license to make, have made, use,
offer to sell, sell, import, and otherwise transfer the Work, where such license
applies only to those patent claims licensable by such Contributor that are
necessarily infringed by their Contribution alone or by combination of their
Contribution with the Work to which such Contribution was submitted. If You
institute patent litigation against any entity alleging that the Work or a
Contribution incorporated within the Work constitutes direct or contributory
patent infringement, then any patent licenses granted to You under this License
for that Work shall terminate as of the date such litigation is filed.

4. Redistribution. You may reproduce and distribute copies of the Work or
Derivative Works thereof in any medium, with or without modifications, and in
Source or Object form, provided that You meet the following conditions:

(a) You must give any other recipients of the Work or Derivative Works a copy of
this License; and

(b) You must cause any modified files to carry prominent notices stating that
You changed the files; and

(c) You must retain, in the Source form of any Derivative Works that You
distribute, all copyright, patent, trademark, and attribution notices from the
Source form of the Work, excluding those notices that do not pertain to any part
of the Derivative Works; and

(d) If the Work includes a "NOTICE" text file as part of its distribution, then
any Derivative Works that You distribute must include a readable copy of the
attribution notices contained within such NOTICE file, excluding those notices
that do not pertain to any part of the Derivative Works, in at least one of the
following places: within a NOTICE text file distributed as part of the Derivative
Works; within the Source form or documentation, if provided along with the
Derivative Works; or within a display generated by the Derivative Works, if and
wherever such third-party notices normally appear.

You may add Your own copyright statement to Your modifications and may provide
additional or different license terms and conditions for use, reproduction, or
distribution of Your modifications, or for any such Derivative Works as a whole,
provided Your use, reproduction, and distribution of the Work otherwise complies
with the conditions stated in this License.

5. Submission of Contributions. Unless You explicitly state otherwise, any
Contribution intentionally submitted for inclusion in the Work by You to the
Licensor shall be under the terms and conditions of this License, without any
additional terms or conditions.

6. Trademarks. This License does not grant permission to use the trade names,
trademarks, service marks, or product names of the Licensor, except as required
for reasonable and customary use in describing the origin of the Work and
reproducing the content of the NOTICE file.

7. Disclaimer of Warranty. Unless required by applicable law or agreed to in
writing, Licensor provides the Work on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied, including, without
limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT,
MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely
responsible for determining the appropriateness of using or redistributing the
Work and assume any risks associated with Your exercise of permissions under
this License.

8. Limitation of Liability. In no event and under no legal theory, whether in
tort (including negligence), contract, or otherwise, unless required by
applicable law or agreed to in writing, shall any Contributor be liable to You
for damages, including any direct, indirect, special, incidental, or
consequential damages of any character arising as a result of this License or
out of the use or inability to use the Work (including but not limited to
damages for loss of goodwill, work stoppage, computer failure or malfunction,
or any and all other commercial damages or losses), even if such Contributor has
been advised of the possibility of such damages.

9. Accepting Warranty or Additional Liability. While redistributing the Work or
Derivative Works thereof, You may choose to offer, and charge a fee for,
acceptance of support, warranty, indemnity, or other liability obligations
and/or rights consistent with this License. However, in accepting such
obligations, You may act only on Your own behalf and on Your sole
responsibility, not on behalf of any other Contributor, and only if You agree to
indemnify, defend, and hold each Contributor harmless for any liability incurred
by, or claims asserted against, such Contributor by reason of your accepting any
such warranty or additional liability.

END OF TERMS AND CONDITIONS

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
