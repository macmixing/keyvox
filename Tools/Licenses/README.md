# Portable speech dependency provenance

This record covers material used by the Android experiment. Third-party material
keeps its original license; the KeyVox source license is MIT.

| Material | Provenance and license | Distribution status |
| --- | --- | --- |
| Whisper / GGML CPU | v1.7.6 source archive pinned by SHA-256 in `build-portable-whisper.sh`; MIT | CPU notices installed with libraries |
| GGML embedded llamafile matrix multiplication | `ggml/src/ggml-cpu/llamafile/sgemm.cpp`; Mozilla Foundation, MIT | Full notice retained |
| GGML attention implementation | `ggml/src/ggml-cpu/ops.cpp`; Jeffrey Quesnelle and Bowen Peng, MIT | Attribution retained with MIT terms |
| GGML adapted exponential routines | Arm optimized routines; MIT OR Apache-2.0 WITH LLVM-exception | Full upstream license and attribution retained; matched source linked in root notices |
| Android C++ support runtime | NDK 30.0.16138531 `libc++_shared.so`; LLVM Apache-2.0 WITH LLVM-exception and legacy permissive notices | Selected NDK's complete notices installed with libraries |
| Swift Android SDK runtime and Foundation dependencies | Swift 6.3.3 Android artifact bundle, including its `sbom.spdx.json` | UNRESOLVED: SDK SBOM lists Swift, libxml2, curl and BoringSSL, but a complete notice/provenance record for linked ICU and other static components is still required before binary distribution |
| Whisper model used for device verification | `ggerganov/whisper.cpp` conversion of OpenAI Whisper `ggml-tiny.en.bin`; upstream code and weights MIT | Local verification artifact; not bundled by this experiment; immutable model identity and conversion provenance still need recording before redistribution |
| Existing bundled Silero VAD model | `KeyVoxVoiceActivity` resource `ggml-silero-v5.1.2` | UNRESOLVED: verify exact existing artifact origin, conversion and model notice before distributing the Android harness |
| Speech recording used for device verification | Whisper v1.7.6 `samples/jfk.wav` | Local verification only; not incorporated in repository or distribution |

The native build installs `share/licenses/keyvox-speech`. Include that directory
with redistributed native binaries. It covers the native components above, not
the unresolved Swift SDK/model distribution records. No additional NLP package,
model, corpus or lexicon has been adopted by the experiment.
