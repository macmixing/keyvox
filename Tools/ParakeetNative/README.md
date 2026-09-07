# Portable Parakeet native runtime

This builds an optional Android arm64 CPU library for the existing Parakeet
backend boundary. It does not change the Apple backend or the Swift package graph.

```sh
ANDROID_NDK_ROOT=/path/to/android/ndk \
  bash Tools/ParakeetNative/build-android.sh /tmp/keyvox-parakeet-android
```

Requires Git, CMake, Python 3, and the Android NDK. The verified toolchain is NDK
30.0.16138531, targeting Android API 28. Distribute the installed notices with the
library and the matching NDK `libc++_shared.so`. Do not substitute another C++
runtime without rebuilding and checking both speech libraries together.

## Native isolation

Parakeet and Whisper embed different GGML revisions. `libparakeet.so` statically
contains its GGML and exports only `parakeet_capi_*`; an ELF version script hides
everything else. The build rejects unexpected exports or dynamic dependencies.
GPU, OpenMP, BLAS, llamafile, HBM, dynamically loaded backends, and KleidiAI are
disabled. No optional dependency is fetched. Linux can reuse this ELF boundary;
Windows will need its own export configuration. Neither platform is verified here.

## Source and licenses

| Material | Pinned source | License |
| --- | --- | --- |
| parakeet.cpp, including in-tree patches | [e75de9b6b9b688fd293aa22f7e27aa724ea286f8](https://github.com/mudler/parakeet.cpp/tree/e75de9b6b9b688fd293aa22f7e27aa724ea286f8) | MIT, parakeet.cpp authors |
| GGML | [e705c5fed490514458bdd2eaddc43bd098fcce9b](https://github.com/ggml-org/ggml/tree/e705c5fed490514458bdd2eaddc43bd098fcce9b) | MIT, GGML authors |
| dr_wav 0.14.6 | `third_party/dr_wav.h` in the pinned Parakeet tree | MIT-0 alternative selected, David Reid |
| GGML YaRN attention | `src/ggml-cpu/ops.cpp` in pinned GGML | MIT, Jeffrey Quesnelle and Bowen Peng |
| Arm exp approximations | `src/ggml-cpu/vec.h` in pinned GGML; [matching routine family](https://android.googlesource.com/platform/external/arm-optimized-routines/+/0a6ab6d1f600a2fba6509440f455300a606024e6/math/aarch64/advsimd/v_expf_inline.h) | MIT OR Apache-2.0 WITH LLVM-exception |
| NDK runtime/compiler material | Installed NDK `NOTICE` and `NOTICE.toolchain` | LLVM/Android component notices copied in full |

The build verifies both Git revisions and the parent's GGML gitlink. It applies
the pinned upstream patch series, preserving its authorship (including Ettore Di
Giacinto's broadcast-fold patch). Patch failures are fatal. This wrapper changes
export visibility and build options; it makes no additional source modifications.
Full root licenses are installed directly from the verified source trees;
`CPU-NOTICES.txt` supplies the embedded component notices. The Arm notice is shared
with the already audited Whisper distribution, with this newer GGML provenance.

Dynamic dependency inventory: Android `libc`, `libm`, `libdl`, and NDK
`libc++_shared`. No Python, NeMo, SentencePiece library, training corpus, server,
or model weights are included in this native library.

## Runtime trial and remaining work

The pinned CPU runner executed on SM-S948U1 and transcribed the existing
11-second speech fixture with word timestamps. It also transcribed the existing
5.6-second device microphone capture in 1.016 seconds wall time, including model
loading (one measured run, not a benchmark). User audio remains on the device.
These are native-runner results; the Swift backend connection remains unresolved.

The trial used `tdt-0.6b-v3-q8_0.gguf`, 940,663,680 bytes, SHA-256
`4d69a4a6683f4f2d952bad794c1357ca6eb628027695b4699c5a9ad4cd07d757`, from
[mudler/parakeet-cpp-gguf revision bf0af9f425fa01809cadec671b3cb672709d13e9](https://huggingface.co/mudler/parakeet-cpp-gguf/tree/bf0af9f425fa01809cadec671b3cb672709d13e9).
Downloaded bytes matched this published hash. Its published CC BY 4.0 terms
permit commercial distribution alongside MIT code; weights retain their separate
license. The source is NVIDIA's
[Parakeet TDT 0.6B v3 revision 541d1f99c6b0c3cd0b11a95167540bb8edefd82b](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/tree/541d1f99c6b0c3cd0b11a95167540bb8edefd82b).
Redistributing weights requires NVIDIA/converter attribution, source and
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode.en) terms,
retained notices, and the GGUF/selective Q8 quantization modification history.
This tool neither downloads nor distributes weights. Model cards declare training
provenance; this is not an independent attestation of the underlying corpus rights.

The native API cannot abort active inference. A Swift adapter must serialize
native calls, discard cancelled results, and defer freeing the context until the
call completes. It must not report immediate native cancellation. This model
ignores language prompts and supplies no detected-language result; callers must
not infer detected language from the requested hint. Dictionary correction stays
in the existing downstream KeyVox processing layer.
