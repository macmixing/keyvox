# KeyVoxVoiceActivity Binary Artifact Provenance

## whisper.xcframework

`whisper.xcframework` is built from the official `ggml-org/whisper.cpp` release source by `build-whisper-xcframework.sh`.

- Upstream repository: <https://github.com/ggml-org/whisper.cpp>
- Release tag: `b5130`
- Source commit: `927cfce34f31707e17f2bff35c349632fb9e2c3a`
- License: MIT

## Why This Artifact Is Built Here

The upstream release framework embeds ggml's Metal kernels as source. ggml creates its Metal device when a process first touches whisper.cpp, including a CPU-only voice activity detector, and compiles that source then. A new process with empty caches spent 12 to 25 seconds there on the iPhones measured, and the Transcription AU keeps its caches apart from the containing app's.

This build compiles the kernels ahead of time into `default.metallib`, plus `ggml-tensor.metallib` for GPUs with the Metal tensor API, and places them in each framework's resources, where ggml loads them instead of compiling source. As in ggml's own precompiled build, the bfloat16 kernels are left out: ggml enables them only when it compiles source at runtime on a GPU that supports them, and whisper.cpp at this release creates no bfloat16 tensors. Every other build option matches the upstream release script.

## Retained Slices

- `ios-arm64`
- `ios-arm64_x86_64-simulator`
- `macos-arm64_x86_64`

## Rebuild Steps

```sh
Packages/KeyVoxVoiceActivity/Artifacts/build-whisper-xcframework.sh /tmp/keyvox-whisper-build
```

The script clones the release tag, checks that it still points at the source commit above, builds the three slices, and replaces `whisper.xcframework` next to it.
