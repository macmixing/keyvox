# KeyVoxLocalInference Binary Artifact Provenance

## llama.xcframework

`llama.xcframework` is vendored from the official `ggml-org/llama.cpp` Apple XCFramework release artifact.

- Upstream repository: <https://github.com/ggml-org/llama.cpp>
- Release tag: `b9093`
- Release metadata source: <https://api.github.com/repos/ggml-org/llama.cpp/releases/latest>
- Downloaded asset: `llama-b9093-xcframework.zip`
- Asset URL: <https://github.com/ggml-org/llama.cpp/releases/download/b9093/llama-b9093-xcframework.zip>
- License: MIT

## Why This Artifact Is Vendored

KeyVox uses this framework through `KeyVoxLocalInference` for local Vibes rewrite inference. The `b9093` artifact includes the Metal backend needed for Mac Vibes GPU offload. The Swift runtime gates GPU layer offload to macOS 15 and newer; older macOS releases and all iOS builds intentionally stay CPU-only.

## Retained Slices

The upstream release zip includes additional Apple platforms. KeyVox trims the vendored artifact to the platform surface used by this package:

- `ios-arm64`
- `ios-arm64_x86_64-simulator`
- `macos-arm64_x86_64`

The `ggml-metal.h` header is expected in each retained slice, and the macOS binary is expected to expose Metal backend symbols.

## Rebuild Steps

```sh
curl -L https://api.github.com/repos/ggml-org/llama.cpp/releases/latest -o /tmp/llama-latest-release.json
curl -L https://github.com/ggml-org/llama.cpp/releases/download/b9093/llama-b9093-xcframework.zip -o /tmp/llama-b9093-xcframework.zip
unzip -q /tmp/llama-b9093-xcframework.zip -d /tmp/llama-b9093-xcframework

xcodebuild -create-xcframework \
  -framework /tmp/llama-b9093-xcframework/build-apple/llama.xcframework/ios-arm64/llama.framework \
  -framework /tmp/llama-b9093-xcframework/build-apple/llama.xcframework/ios-arm64_x86_64-simulator/llama.framework \
  -framework /tmp/llama-b9093-xcframework/build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework \
  -output /tmp/keyvox-llama-b9093-trimmed.xcframework

ditto /tmp/keyvox-llama-b9093-trimmed.xcframework Packages/KeyVoxLocalInference/Artifacts/llama.xcframework
```

## Validation Notes

On macOS 15 and newer, the Mac live inference proof for this artifact should report a Metal backend similar to:

```text
gpu-offload mode=automatic supported=true action=attempt layers=-1 devices=count=3 [0:MTL0:Apple M2,1:BLAS:Accelerate,2:CPU:Apple M2]
gpu-offload mode=automatic backend=gpu layers=-1
```

On older macOS releases, the runtime should instead log CPU fallback before enumerating Metal devices. If a macOS 15+ log shows no `MTL` device, the vendored artifact or llama backend initialization path is wrong.
