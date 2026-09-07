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
| Swift Android SDK runtime and Foundation dependencies | Swift 6.3.3 Android artifact bundle; Apache-2.0 with runtime exceptions, LLVM terms, ICU/Unicode and component-specific permissive terms | Complete version-matched notices and actual archive identities retained in `Swift-Android`; exact build-source checkout reproducibility remains limited by SDK metadata |
| Whisper model used for device verification | `ggerganov/whisper.cpp` conversion of OpenAI Whisper `ggml-tiny.en.bin`; upstream code and weights MIT | Exact local bytes match immutable published LFS identity in `runtime-models.lock.json`; model not bundled; full OpenAI notice retained |
| Existing bundled Silero VAD model | Published GGML conversion of Silero v5.1.2, MIT | Exact bundled bytes match immutable published LFS identity; full pinned Silero notice now included in the resource bundle |
| Speech recording used for device verification | Whisper v1.7.6 `samples/jfk.wav` | Local verification only; not incorporated in repository or distribution |

The native build installs `share/licenses/keyvox-speech`. Include that directory
with redistributed native binaries. Also include `Swift-Android`, relevant model
notices, and the complete notices inside SwiftPM resource bundles. Original terms
remain applicable; these third-party components are not relicensed to MIT.

The model record identifies published conversion artifacts, their licenses, and
the exact verified bytes. It does not claim independent reproduction of their
historical conversion commands. No additional NLP model or corpus has yet been
adopted by the experiment. Existing manually edited pronunciation data is unchanged.
