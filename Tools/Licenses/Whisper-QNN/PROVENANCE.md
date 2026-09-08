# Optional Whisper Base compiled encoder

The optional Qualcomm encoder retains the multilingual OpenAI Whisper Base model and existing Whisper decoder. Original weights and Whisper code are MIT licensed; the retained license is `../WHISPER-MODEL-LICENSE.txt`.

- Compiled artifact: Qualcomm AI Hub Models `whisper_base`, release `v0.61.0`, float QNN context binary for Snapdragon 8 Elite Gen 5 for Galaxy.
- Artifact URL, archive/member hashes, byte count, and paired Base SHA-256 are pinned in `Packages/KeyVoxModels/Sources/KeyVoxModels/WhisperEncoderArtifact.swift`.
- Model card: https://huggingface.co/qualcomm/Whisper-Base — identifies `openai/whisper-base` and links the Transformers v4.42.3 Apache-2.0 license, retained here. This implementation license does not replace the original weights' MIT license.
- Export source: https://github.com/qualcomm/ai-hub-models/tree/v0.61.0/src/qai_hub_models/models/_shared/hf_whisper — BSD-3-Clause, retained here. The upstream recipe does not pin a checkpoint revision; binary hashes identify the evaluated release, not a reproducible export claim.
- No Python export environment, decoder context binary, datasets, or third-party audio fixtures are packaged. Validation uses maintainer-provided recordings.

## Qualcomm runtime

The externally supplied QAIRT 2.45.0.260326 SDK and headers use the Qualcomm AI Stack Software License Agreement. They are not MIT-licensed KeyVox source. The selected runtime files and license/notice hashes are pinned in `Native/WhisperQNN/runtime.lock.json`. Android staging preserves the SDK license and QNN_NOTICE alongside the application binaries. Vendor `libcdsprpc.so` is supplied by the device and is not redistributed.

The independently written KeyVox native adapter is MIT licensed. No Qualcomm SDK headers or sample implementation are copied into its sources.

**Distribution verification remains unresolved:** the SDK-wide QNN_NOTICE references Eigen and MPL/LGPL material without mapping it to individual runtime binaries. Inclusion of LGPL in this selected subset has not been established. The selected subset's exact component versions, covered files, and corresponding-source obligations still require version-specific evidence before distribution is declared cleared. The SDK object-code redistribution grant does not eliminate third-party obligations.
