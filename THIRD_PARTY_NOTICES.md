# Third-Party Notices

This project is primarily licensed under MIT for source code (see [our license](https://github.com/macmixing/keyvox/blob/main/LICENSE.md)).
Third-party components, data, and fonts remain under their original licenses.

### Optional perceptron linguistic inference

- The Swift inference feature schema adapts the specifically MIT-licensed
  `nltk/tag/perceptron.py` from NLTK 3.9.1, attributed to Matthew Honnibal and
  the NLTK Project. Full terms are in
  `Packages/KeyVoxLinguistics/THIRD_PARTY_NOTICES.md` and the package resource
  `PERCEPTRON-LICENSE.txt`; retain that notice with distributed binaries.
- Optional model JSON assets in `Tools/Models/averaged-perceptron-tagger-eng`
  are MIT-licensed. That directory retains the full license, immutable upstream
  license declaration, and artifact hashes. Retain its license when distributing
  the model. These assets are not embedded in shared Swift packages.

### Princeton WordNet 3.0 lexical indexes

- Source: <https://wordnet.princeton.edu/>
- License: WordNet 3.0 License
- Bundled subset: unchanged noun, verb, adjective, and adverb index files retained
  in `Tools/Models/wordnet-3.0` for portable lexical-role resolution.

WordNet Release 3.0

This software and database is being provided to you, the LICENSEE, by Princeton
University under the following license. By obtaining, using and/or copying this
software and database, you agree that you have read, understood, and will comply
with these terms and conditions.:

Permission to use, copy, modify and distribute this software and database and its
documentation for any purpose and without fee or royalty is hereby granted,
provided that you agree to comply with the following copyright notice and
statements, including the disclaimer, and that the same appear on ALL copies of
the software, database and documentation, including modifications that you make
for internal use or for distribution.

WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved.

THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" AND PRINCETON UNIVERSITY MAKES NO
REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED. BY WAY OF EXAMPLE, BUT NOT
LIMITATION, PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES OF
MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF THE
LICENSED SOFTWARE, DATABASE OR DOCUMENTATION WILL NOT INFRINGE ANY THIRD PARTY
PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.

The name of Princeton University or Princeton may not be used in advertising or
publicity pertaining to distribution of the software and/or database. Title to
copyright in this software, database and any associated documentation shall at
all times remain with Princeton University and LICENSEE agrees to preserve same.

## Runtime Components

### whisper.cpp / GGML (Apple XCFramework and portable CPU libraries)
- Upstream: <https://github.com/ggml-org/whisper.cpp>
- License: MIT
- Note: bundled through `Packages/KeyVoxVoiceActivity` and used by `Packages/KeyVoxWhisper`
- Apple XCFramework: built from release `b5130` source, commit `927cfce34f31707e17f2bff35c349632fb9e2c3a`, by `Packages/KeyVoxVoiceActivity/Artifacts/build-whisper-xcframework.sh`.
- Portable source version: v1.7.6, archive SHA-256 `166140e9a6d8a36f787a2bd77f8f44dd64874f12dd8359ff7c1f4f9acb86202e`.
- Bundled CPU code also includes Mozilla Foundation's MIT-licensed llamafile matrix multiplication, MIT-licensed attention code by Jeffrey Quesnelle and Bowen Peng, and adapted Arm optimized routines (MIT OR Apache-2.0 WITH LLVM-exception). Full notices are in `Tools/Licenses/Whisper-CPU-NOTICES.txt` and installed alongside the portable libraries.
- Arm provenance: the exponential routine's constants and reduction sequence match [this pinned upstream source](https://android.googlesource.com/platform/external/arm-optimized-routines/+/0a6ab6d1f600a2fba6509440f455300a606024e6/math/aarch64/advsimd/v_expf_inline.h). This identifies the routine family, not the exact historical import commit. The full upstream Arm license is retained.

Copyright (c) The ggml authors

### Android C++ runtime
- Source: the Android NDK selected by `ANDROID_NDK_ROOT`; the verified device build used NDK `30.0.16138531`.
- Redistributed runtime: `libc++_shared.so`, with LLVM libc++/libc++abi support; Apache-2.0 WITH LLVM-exception and retained legacy permissive notices.
- The portable build installs the selected NDK's complete `NOTICE` and `NOTICE.toolchain` under `share/licenses/keyvox-speech`. Keep these with distributed native binaries; these aggregate notices also describe build tools that are not shipped in KeyVox.
- KeyVox's original source remains MIT. Third-party license texts and attribution obligations remain applicable to their respective components.

### OpenAI Whisper (code + model weights)
- Upstream: <https://github.com/openai/whisper>
- License: MIT
- Note: model artifacts are downloaded by the app at runtime

Copyright (c) 2022 OpenAI

The Android verification model's immutable identity and full MIT notice are
recorded in `Tools/Licenses/runtime-models.lock.json` and
`Tools/Licenses/WHISPER-MODEL-LICENSE.txt`. This experiment does not bundle that
downloaded Whisper model.

### Bundled Silero VAD model
- Upstream: <https://github.com/snakers4/silero-vad>
- License: MIT, Copyright (c) 2020-present Silero Team.
- The exact published GGML v5.1.2 conversion is pinned in `Tools/Licenses/runtime-models.lock.json`.
- The complete notice ships beside the model as `Packages/KeyVoxVoiceActivity/Sources/KeyVoxVoiceActivity/Resources/SILERO-LICENSE.txt`.

### Swift Android runtime

Full runtime and incorporated-data notices, the installed SDK SBOM, and verified
archive identities are retained in `Tools/Licenses/Swift-Android`. Its README
distinguishes the observed executable's linked components from the wider SDK,
records required cryptography acknowledgments where applicable, and explains
the limits of available source-build provenance. Include those notices with
redistributed Android binaries in addition to native and model notices.

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

### Hex (emoji renderer source)
- Upstream: <https://github.com/anomalyco/hex>
- License: MIT
- Note: the iOS keyboard's emoji renderer, `iOS/KeyVox Keyboard/Core/Emoji/KeyboardEmojiGlyphRenderer.swift`, is adapted from Hex's `EmojiGlyphRenderer` (`ios/HEXShared/FullKeyboard/Emoji/EmojiGlyphs.swift`).

Copyright (c) 2026 Christopher Langton

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
  - `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/polished-alpha-028-lora.gguf`
  - `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/casual-alpha-9-lora.gguf`
- Compatible base model: `Qwen2.5-0.5B-Instruct`
- Upstream base model: <https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct>
- Base model license: Apache License 2.0
- Note: These are KeyVox-trained LoRA adapter artifacts for local Vibes rewrite behavior. They are product-specific model adapter assets bundled with the app and are not part of the repository's MIT-licensed source code.

### AOSP LatinIME (bundled predictive-keyboard engine source)
- Upstream: <https://android.googlesource.com/platform/packages/inputmethods/LatinIME/>
- Upstream revision: `127336e9f29d69607eab55982324b210279ae8c5`
- License: Apache License 2.0
- License URL: <https://www.apache.org/licenses/LICENSE-2.0>
- Note: Selected native LatinIME source is bundled through `Packages/KeyVoxPredictiveKeyboard` and connected to a KeyVox-specific portable bridge and ranking pipeline.

Copyright (c) 2008, The Android Open Source Project

### English Speller Database / SCOWL (bundled predictive-keyboard data)
- Upstream: <https://github.com/en-wl/wordlist>
- Upstream revision: `1e5b7d3a72f47a71da5d28686c1dd4b397178485`
- License: ESDB permissive notice
- Note: KeyVox generates its word lists from SCOWL at variant level 2: size 60 American (A) for the predictive keyboard's dictionary and its next-word lists; size 60 and size 50 American for the capitalized-spelling list it shares with dictation; size 60 in every spelling (American, British -ise, British -ize, Canadian, and Australian: A, B, Z, C, D) for its accent-suggestion overlay; size 50 in every spelling, with the dictionary's words, for the words it never corrects; and size 80 in every spelling, whose words the swipe-vocabulary list never leaves out as misspellings.

Copyright 2000-2026 by Kevin Atkinson

Permission to use, copy, modify, distribute, and sell any part of the English
Speller Database (ESDB, previously known as SCOWLv2), or word lists created
from it, is hereby granted without fee, provided that the above copyright
notice appears in all copies and that both the above copyright notice and this
notice appear in supporting documentation. Kevin Atkinson makes no
representations about the suitability of this database for any purpose. It is
provided "as is" without express or implied warranty.

### Tatoeba English sentences (derived predictive-keyboard data)
- Source: <https://tatoeba.org/en/downloads>
- License: CC BY 2.0 FR
- License URL: <https://creativecommons.org/licenses/by/2.0/fr/deed.en>
- Note: English sentences were normalized, aggregated, and transformed into non-reversible dictionary-frequency and previous-word count artifacts bundled with `Packages/KeyVoxPredictiveKeyboard`, and into its non-reversible word, word-pair, and word-sequence count artifact and sentence-opener, capitalized-spelling, next-word, grammar-word, and swipe-vocabulary lists. `Tools/KeyVoxLanguageModel` rebuilds the count artifact and the lists. The package's typing regression check holds 30 of the sentences, lowercased and without punctuation, as test cases (`Tests/KeyVoxPredictiveKeyboardTests/Fixtures/typing_regression/en/cases.jsonl`).

Attribution: Based on sentence data contributed by the Tatoeba community.

### OpenAssistant OASST1 (derived predictive-keyboard data)
- Source: <https://huggingface.co/datasets/OpenAssistant/oasst1>
- License: Apache License 2.0
- License URL: <https://www.apache.org/licenses/LICENSE-2.0>
- Note: English training messages were normalized, aggregated, and transformed into non-reversible dictionary-frequency and previous-word count artifacts bundled with `Packages/KeyVoxPredictiveKeyboard`.

Attribution: Based on the OpenAssistant OASST1 dataset created by the OpenAssistant contributors.

### OpenAssistant OASST2 (derived predictive-keyboard data)
- Source: <https://huggingface.co/datasets/OpenAssistant/oasst2>
- License: Apache License 2.0
- License URL: <https://www.apache.org/licenses/LICENSE-2.0>
- Note: English messages were normalized, aggregated, and transformed into the non-reversible word, word-pair, and word-sequence count artifact and the non-reversible sentence-opener, capitalized-spelling, next-word, grammar-word, and swipe-vocabulary lists bundled with `Packages/KeyVoxPredictiveKeyboard`. `Tools/KeyVoxLanguageModel` rebuilds them.

Attribution: Based on the OpenAssistant OASST2 dataset created by the OpenAssistant contributors.

### YouTube-Commons (derived predictive-keyboard data)
- Source: <https://huggingface.co/datasets/PleIAs/YouTube-Commons>
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: English transcripts were normalized, aggregated, and transformed into the non-reversible word, word-pair, and word-sequence count artifact and the non-reversible sentence-opener, next-word, grammar-word, and swipe-vocabulary lists bundled with `Packages/KeyVoxPredictiveKeyboard`. The dataset credits each transcript to its creator's channel, title, and link. `Tools/KeyVoxLanguageModel` rebuilds them.

Attribution: Based on YouTube-Commons by PleIAs: transcripts of videos their creators published under the Creative Commons Attribution license, each credited to its channel in the dataset.

### Multilingual typing-language sources (derived predictive-keyboard data)
- Note: The entries below are the sources of the German, Spanish, and French typing-language data that `Tools/KeyVoxLanguageModel` builds: the non-reversible word, word-pair, and word-sequence count artifact and the non-reversible sentence-opener, capitalized-spelling, next-word, and grammar-word lists, and the vocabulary they are built with. `Tools/KeyVoxTypingModels` builds those languages' typing dictionaries (the vocabulary with non-reversible word, word-pair, and word-sequence probabilities from the same counts) and their correction and completion rankers (trained on typing simulated on Tatoeba and OASST2 sentences) from that data. German's are bundled with `Packages/KeyVoxPredictiveKeyboard` (`PredictiveData/de`) and its capitalized-spelling list with `Packages/KeyVoxLinguistics`; Spanish's and French's are not bundled yet. Tatoeba, OASST2, and YouTube-Commons are credited above, and their German, Spanish, and French text is used the same way.

### Tatoeba German, Spanish, and French sentences (derived predictive-keyboard data)
- Source: <https://tatoeba.org/en/downloads>
- License: CC BY 2.0 FR
- License URL: <https://creativecommons.org/licenses/by/2.0/fr/deed.en>
- Note: German, Spanish, and French sentences were normalized, aggregated, and transformed into the non-reversible artifacts and lists described above. The predictive keyboard package's typing regression check holds 30 German sentences, lowercased and without punctuation, as test cases (`Tests/KeyVoxPredictiveKeyboardTests/Fixtures/typing_regression/de/cases.jsonl`).

Attribution: Based on sentence data contributed by the Tatoeba community.

### YODAS2 (derived predictive-keyboard data)
- Source: <https://huggingface.co/datasets/espnet/yodas2>
- License: CC BY 3.0
- License URL: <https://creativecommons.org/licenses/by/3.0/>
- Note: German, Spanish, and French captions written by hand were normalized, aggregated, and transformed into the non-reversible count artifact. The dataset credits each caption to its video.

Attribution: Based on YODAS2 by Li et al. (ESPnet): manual captions of videos published under Creative Commons licenses.

### WildChat-4.8M (derived predictive-keyboard data)
- Source: <https://huggingface.co/datasets/allenai/WildChat-4.8M>
- License: Open Data Commons Attribution License (ODC-By) 1.0
- License URL: <https://opendatacommons.org/licenses/by/1-0/>
- Note: German, Spanish, and French user messages of up to 50 words were normalized, aggregated, and transformed into the non-reversible count artifact and sentence-opener lists.

Attribution: Based on the WildChat-4.8M dataset by the Allen Institute for AI (Zhao et al., 2024).

### 88milSMS (derived predictive-keyboard data)
- Source: <https://hdl.handle.net/11403/comere/cmr-88milsms/cmr-88milsms-tei-v1>
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: French text messages were normalized, aggregated, and transformed into the non-reversible count artifact and sentence-opener lists.

Attribution: Based on 88milSMS (Panckhurst et al., CoMeRe corpus, ORTOLANG): text messages collected in Montpellier, France, in 2011.

### Open Discourse (derived predictive-keyboard data)
- Source: <https://doi.org/10.7910/DVN/FIKIBO>
- License: CC0 1.0
- License URL: <https://creativecommons.org/publicdomain/zero/1.0/>
- Note: Speeches of the German Bundestag from 2000 on were normalized, aggregated, and transformed into a variant of the German count artifact.

Attribution: Based on Open Discourse (Richter et al.): the speeches of the German Bundestag.

### AOSP LatinIME word lists (derived predictive-keyboard data)
- Upstream: <https://android.googlesource.com/platform/packages/inputmethods/LatinIME/+/127336e9f29d69607eab55982324b210279ae8c5/dictionaries/>
- Upstream revision: `127336e9f29d69607eab55982324b210279ae8c5`
- License: Apache License 2.0
- License URL: <https://www.apache.org/licenses/LICENSE-2.0>
- Note: The German, Spanish, and French vocabularies are modified versions of the `de`, `es`, and `fr` word lists: single words only, with their capitals settled by Wikidata Lexemes, Grammalecte, and RLA-ES, and the German one with the Wikidata Lexemes words its sentences write as often as the list's own words, which the list lacks. The typing dictionaries `Tools/KeyVoxTypingModels` builds for those languages hold the vocabularies' words in lowercase.

Copyright (c) 2008, The Android Open Source Project

### Wikidata Lexemes (derived predictive-keyboard data)
- Source: <https://dumps.wikimedia.org/wikidatawiki/entities/>
- License: CC0 1.0
- License URL: <https://creativecommons.org/publicdomain/zero/1.0/>
- Note: German, Spanish, and French word forms and their lexical categories settle the capitals in the vocabularies and tell German nouns from names; German forms its sentences write often fill in the words the German word list lacks.
- Note: `Tools/KeyVoxEmojiData` reads the German, Spanish, and French nouns' forms from the dump of November 18, 2026, so `KeyVoxEmoji`'s search data for those languages finds a noun's emoji by its other forms, such as its plural.

Attribution: Based on Wikidata Lexemes.

### Grammalecte French lexicon (derived predictive-keyboard data)
- Source: <https://grammalecte.net/>
- Upstream version: 7.7
- License: Mozilla Public License 2.0
- License URL: <https://www.mozilla.org/en-US/MPL/2.0/>
- Note: The French vocabulary takes spellings from the lexicon's inflected forms and settles capitals with them. The French vocabulary, and files built from it, are covered by the Mozilla Public License 2.0 and available in source form in this repository.

Attribution: Based on the Grammalecte French lexicon v7.7 by Olivier R.

### RLA-ES Spanish spelling dictionaries (build-time capitalization check)
- Source: <https://github.com/sbosio/rla-es>
- Upstream version: 2.9
- License: Mozilla Public License 1.1 or later (one of its GPL 3+, LGPL 3+, and MPL 1.1+ options)
- License URL: <https://www.mozilla.org/en-US/MPL/1.1/>
- Note: The generic Spanish dictionary decides which capitalized words of the Spanish vocabulary are written in lowercase; none of its files are copied into it.

Attribution: Based on the RLA-ES Spanish spelling dictionaries v2.9 by Santiago Bosio and contributors.

### UD Spanish AnCora (derived predictive-keyboard data)
- Source: <https://github.com/UniversalDependencies/UD_Spanish-AnCora>
- Upstream version: Universal Dependencies release 2.19
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: Each Spanish word's most common part of speech in the treebank was aggregated into the non-reversible word kinds the Spanish sentence-opener and grammar-word lists are built from.

Attribution: Based on UD Spanish AnCora (Taulé, Martí, and Recasens; Universal Dependencies release 2.19).

### Aalto ITE Typing dataset (derived predictive-keyboard rankers)
- Source: <https://doi.org/10.5281/zenodo.12528163>
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: KeyVox trained correction, completion, and conservative action-ranking artifacts from the dataset. The bundled model artifacts are adaptations and do not contain the original typing-event records. The dataset's typing also calibrates the typo simulator whose simulated typing trains the German, Spanish, and French rankers `Tools/KeyVoxTypingModels` builds.

Attribution: Based on Leino, Laine, Kurimo, and Oulasvirta, *Mobile Typing with Intelligent Text Entry: A Large-Scale Dataset and Results* (2024).

### swipe.futo.org (derived swipe-typing model, swipe vocabulary words, and test data)
- Source: <https://huggingface.co/datasets/futo-org/swipe.futo.org> (revision `d71bf5fd7f45b3e7c2ed2d76a21b0dbd3b4ba566`)
- License: MIT
- License URL: <https://huggingface.co/datasets/futo-org/swipe.futo.org/blob/main/LICENSE>
- Note: KeyVox trained and tuned the English swipe-typing model bundled in `Packages/KeyVoxPredictiveKeyboard` (`PredictiveData/en/swipe_encoder.kvsw` and `swipe.json`) on the dataset's swipes, with `Tools/KeyVoxSwipeModel`; the model files do not contain the recordings. The English swipe vocabulary (`PredictiveData/en/swipe_vocabulary.txt`, built by `Tools/KeyVoxLanguageModel`) draws on the words of the training split's sentences, adding words of them that the dictionary and the vocabulary's other words lack; it holds the words alone, without the recordings. The package's swipe test fixtures hold two sets of 300 of the dataset's validation swipes: one resampled, for decoding (`Tests/KeyVoxPredictiveKeyboardTests/Fixtures/swipe_parity.json`), and one as recorded, with its touch points, key centers, and the loop found at each key, for loop finding (`Tests/KeyVoxPredictiveKeyboardTests/Fixtures/swipe_key_loops.json`).

Attribution: Based on the swipe.futo.org dataset collected by FUTO.

Copyright (c) 2025 FUTO

### Profanity List (build-time word filter)
- Source: <https://github.com/dsojevic/profanity-list> (revision `c27924319aa9bd6f917e3782b4f4b6604a50b652`)
- License: MIT
- License URL: <https://github.com/dsojevic/profanity-list/blob/c27924319aa9bd6f917e3782b4f4b6604a50b652/LICENSE>
- Note: The predictive keyboard's English dictionary, swipe vocabulary, and capitalized-spelling list leave out the words that the list's English terms tagged racial or anti-LGBTQ, or religious at strong severity or above, match (`Tools/KeyVoxTypingModels/offensive_words.py`); none of its files are copied into them. The list has no German, Spanish, or French terms, and is not used for those languages (German and French use Multilingual HateCheck, below).

Copyright (c) 2021 David Sojevic

### Multilingual HateCheck (build-time word filter)
- Source: <https://huggingface.co/datasets/Paul/hatecheck-german> (revision `5229a5cc475f36c08d03ca52f0ccb005705e60d2`) and <https://huggingface.co/datasets/Paul/hatecheck-french> (revision `5d3085f2129139abc10d2b58becd4d4f2978e5d5`)
- License: CC BY 4.0
- License URL: <https://creativecommons.org/licenses/by/4.0/>
- Note: The German and French typing dictionaries `Tools/KeyVoxTypingModels` builds leave out the slurs of the datasets' slur test cases that target Black, immigrant, Indigenous, gay, trans, Jewish, or Muslim people, in the forms the test cases write them (`Tools/KeyVoxTypingModels/hatecheck_slurs.py`, `offensive_words.py`), and the German capitalized-spelling list `Tools/KeyVoxLanguageModel` builds leaves out the same words; none of its files are copied into them. German's dictionary is bundled with `Packages/KeyVoxPredictiveKeyboard` and its capitalized-spelling list with `Packages/KeyVoxLinguistics`; French's dictionary is not bundled yet.

Attribution: Based on Multilingual HateCheck by Röttger, Seelawi, Nozza, Talat, and Vidgen, *Multilingual HateCheck: Functional Tests for Multilingual Hate Speech Detection Models* (2022).

### MIT License (applies to `whisper.cpp`, OpenAI Whisper, `llama.cpp`, Hex, swipe.futo.org, and the Profanity List above)

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

### Apache License 2.0 (applies to Qwen, AOSP LatinIME, and OpenAssistant components above)

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

### mime-db file-extension registry

- Upstream: <https://github.com/jshttp/mime-db>
- Adopted version: 1.54.0, commit `5207a32f76e77ed2f63421641449f8addeacb0a5`.
- License: MIT, copyright 2014 Jonathan Ong and 2015–2022 Douglas Christopher Wilson.
- Use: non-Apple recognition of known filename extensions in text processing. Only the JSON data is bundled; no JavaScript runtime or npm dependencies are used.
- Source families: IANA registry factual data (CC0), Apache's public-domain `mime.types` mapping, and nginx mapping data (BSD-2-Clause). The release does not identify the exact upstream snapshot revisions.
- Full MIT and nginx notices, the unchanged JSON and checksummed provenance are bundled in `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/FileTypes`.
- Source terms: [IANA](https://www.iana.org/help/licensing-terms), [Apache mapping header](https://raw.githubusercontent.com/apache/httpd/trunk/docs/conf/mime.types), [nginx](https://nginx.org/LICENSE).

### Unicode emoji data and CLDR annotations

- Upstream: Unicode's `emoji-test.txt`, Emoji 18.0 (<https://unicode.org/Public/emoji/latest/emoji-test.txt>); CLDR's English, German, Spanish, Spanish (Latin America), and French annotations and derived annotations, and its parent locales, from <https://github.com/unicode-org/cldr-json> (`cldr-annotations-full`, `cldr-annotations-derived-full`, and `cldr-core`, version 48.2.3); and Unicode's emoji frequency ranking (<https://www.unicode.org/emoji/frequency.html>).
- License: Unicode License v3 (Unicode-3.0), copyright © 1991–2026 Unicode, Inc. Full text: <https://www.unicode.org/license.txt>.
- Use: `KeyVoxEmoji` bundles data written from these sources by `Tools/KeyVoxEmojiData`: each emoji's name and skin-tone versions (`emoji_catalog.txt`), and, for each typing language, the words that find it in search (`<language>/emoji_search.txt`) and the emoji the suggestion bar offers for a word (`<language>/emoji_predictions.txt`). The frequency ranking only orders them.

### Wiktionary (derived dictation phrase lists)

- Upstream: <https://en.wiktionary.org/>
- License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0). Full text: <https://creativecommons.org/licenses/by-sa/4.0/legalcode>.
- Use: `KeyVoxLinguistics` bundles `Resources/punctuation_name_phrases.txt`, phrases in which a punctuation mark's name is an ordinary word, and `Resources/greeting_phrases.txt`, spoken greetings, farewells, and thanks. Both were built from English Wiktionary entry titles and category membership, which were selected, lowercased, and combined with Princeton WordNet 3.0 entries. The greeting list keeps only phrases that Tatoeba English sentences use before a person's name and that WordNet 3.0, Wiktionary's phrasebook, or Apple's lexical classes also mark.
- Use: `KeyVoxLinguistics` also bundles `Resources/example_phrases.txt`, phrases that introduce examples, built from the English Wiktionary entry title `for example` and the synonyms that entry lists for its "as an example" sense, lowercased.
- These three data files are licensed under CC BY-SA 4.0 and are excluded from this repository's MIT source-code license. They are provided as is, without warranties, as described in the license.

Attribution: Based on Wiktionary content contributed by the Wiktionary community.

### Medical Subject Headings (MeSH) (derived dictation phrase list)

- Source: U.S. National Library of Medicine (NLM), <https://www.nlm.nih.gov/mesh/>
- Version: MeSH 2026. These terms reflect MeSH 2026 and may not reflect the most current data available from NLM.
- Terms and conditions: <https://www.nlm.nih.gov/databases/download/terms_and_conditions_mesh.html>
- Use: `KeyVoxLinguistics` `Resources/punctuation_name_phrases.txt` includes medical phrases containing the word "colon" taken from MeSH 2026 topical descriptor terms, with inverted headings written in natural order and lowercased.
- NLM has not endorsed KeyVox. NLM provides the data with no warranties, express or implied, regarding its accuracy or completeness.

Attribution: Courtesy of the U.S. National Library of Medicine.

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
