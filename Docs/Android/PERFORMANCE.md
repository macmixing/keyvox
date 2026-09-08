# Android dictation performance

Measured September 7, 2026 (America/Phoenix), on SM-S948U1 / SM8850, Android 16,
Adreno 840. These observations apply to one device and a caller-owned 5.6-second
recording. They do not establish other-device performance or recognition accuracy.

All trials retain the shared iOS Whisper Base artifact and existing decoder
settings. No quantized or smaller replacement model was used. Android trials use
automatic language detection consistently; changing language selection is not
counted as an optimization. A supplied iOS log for a different 5.59-second
recording reports 1.117 seconds provider inference and 1.378 seconds end to end.
It is a useful reference, not a controlled cross-device benchmark.

## Installed CPU pipeline

| Measurement | First request | Later requests |
| --- | --- | --- |
| Debug Swift, before asynchronous preparation | 5.860 s | 2.501–2.527 s |
| Release Swift, before asynchronous preparation | 5.361 s | 2.495–2.522 s |
| Release Swift, asynchronous preparation, immediate request | 4.776 s | 2.516–2.615 s |
| Release Swift, asynchronous preparation, 6 s setup/recording lead-in | 2.465 s | 2.523–2.578 s |

These are pipeline times, including provider inference. File reading and explicit
model construction are separate: approximately 0.5–4 ms and 69–84 ms respectively
in the final runs. They exclude microphone duration and editor delivery.

Targeted instrumentation measured 2.931 seconds constructing the text processor
on its first use, versus under 0.5 ms subsequently. The Android session now owns
one processor and prepares it on a background task after resource configuration.
Cancellation is checked again after awaiting preparation. This retains processing
and dictionary behavior; it moves preparation before Stop when sufficient time is
available. It does not eliminate startup work: the immediate request still waited
2.301 seconds; after the six-second lead-in the wait was under 0.01 ms.

The real pipeline produced the same nonempty processed output across all repeated
runs. No lexicon/common-word resource was modified. Debug/release APK builds and
debug lint passed. Instrumentation validates finite nonnegative timing values.

## Isolated native runtime

Whisper 1.7.6, Release native code, same audio and Base model, three runs per case:

| Backend | Native inference time |
| --- | --- |
| CPU, 2 threads | 3.036–3.205 s |
| CPU, 4 threads | 2.498–2.542 s |
| CPU, 6 threads | 2.057–2.085 s |
| CPU, 8 threads | 2.188–2.212 s |
| Vulkan, default FP16 | UNRESOLVED: device-lost exception during inference |
| Vulkan, `GGML_VK_DISABLE_F16=1` | 2.414 s first; 1.994–1.997 s repeated |
| Vulkan, only matrix accumulation forced to FP32 | 9.089 s first; 8.068–8.096 s repeated |

All completed variants returned identical native text. GPU initialization logs
confirmed Vulkan model buffers and the Adreno backend. Thread counts were varied
in the probe only; the app retains its existing service configuration. Sequential
trials are preliminary and do not control sustained thermal behavior.

The accumulation-only experiment modifies a temporary source copy at
`ggml_vk_get_mul_mat_mat_pipeline` to select `GGML_PREC_F32`. It is diagnostic,
not a source patch incorporated into KeyVox. Verbose Vulkan tracing materially
slows execution; the table excludes those diagnostic timings.

## Acceleration status and provenance

- CPU remains FUNCTIONAL in the installed app. No GPU-only requirement is added.
- GPU is FUNCTIONAL only in the isolated FP32-mode probe on this device. Automatic
  selection, reliable error recovery, other devices, and installed-app integration
  remain UNRESOLVED. A device-lost crash is not a working CPU fallback.
- The initial probe needed API 35 because upstream directly references
  `vkResetQueryPool`. The optional builder now applies a small patch using
  `vkCmdResetQueryPool` before timestamp writes. API 28 linkage, GPU execution,
  explicit CPU, no-visible-GPU CPU fallback, and timestamp queries pass on the
  connected Android 16 device. Execution on Android 9 remains unverified.
- The GPU build uses the existing MIT Whisper 1.7.6 source/archive, checksum
  `166140e9a6d8a36f787a2bd77f8f44dd64874f12dd8359ff7c1f4f9acb86202e`.
- Investigated build-only Vulkan-Headers revision
  `409c16be502e39fe70dd6fe2d9ad4842ef2c9a53`, archive checksum
  `dc96688e8cf01f2f0a8f31a41fa76a7f8d1e27f022e31bbd3a59ff40a24da9d6`.
  C and `vk_video` headers are Apache-2.0; bundled generated C++ headers offer
  Apache-2.0 or MIT. Select Apache-2.0 and retain full notices if adopted. Separate
  Vulkan-Hpp, generators, samples, and validation layers are not dependencies.
  An independent license review examined these actual header files.
- NDK 30.0.16138531 `glslc` generated shaders from existing MIT runtime sources;
  compiler and device GPU drivers are not bundled. This compiler did not support
  the tested cooperative-matrix shader extensions. The optional native package
  includes the header dependency with its verified complete license and notices;
  the application continues linking the CPU package by default.
- Qualcomm QNN requires separately licensed SDK/runtime material; a permissive
  wrapper does not establish permissive backend redistribution. NPU integration
  remains UNRESOLVED and no QNN material is adopted.

Primary references: [pinned Vulkan build](https://github.com/ggml-org/whisper.cpp/blob/v1.7.6/ggml/src/ggml-vulkan/CMakeLists.txt),
[Vulkan-Headers license files](https://github.com/KhronosGroup/Vulkan-Headers/tree/409c16be502e39fe70dd6fe2d9ad4842ef2c9a53/LICENSES),
[QNN runtime requirements](https://onnxruntime.ai/docs/execution-providers/QNN-ExecutionProvider.html),
[Qualcomm third-party notices](https://github.com/qualcomm/geniex-qairt-plugin/blob/main/THIRD_PARTY_NOTICES.md).

The query-reset change follows the Vulkan 1.0
[command-buffer reset contract](https://docs.vulkan.org/refpages/latest/refpages/source/vkCmdResetQueryPool.html).
It resets the timestamp queries before subsequent writes in submission order;
it does not change inference precision, weights, or device selection.

## Repeat the installed measurement

Stage the engine with `build-engine.py --configuration release` (or `debug` for
the debug comparison), build/install the app and instrumentation APK, and provide
the existing private Float32 fixture and verified Base weights. Then run:

```sh
adb shell am instrument -w -e fixture fixture.f32 -e rounds 3 \
  -e leadInMilliseconds 0 \
  org.keyvox.android.test/org.keyvox.android.ime.ShellInstrumentation
```

Repeat with `-e leadInMilliseconds 6000` to model setup/recording time before the
first request. That delay is excluded from reported processing time and must be
reported with results. Each invocation starts a fresh target process; rounds reuse
its service. `pipelineMilliseconds` includes `inferenceMilliseconds` and processor
preparation wait. Provider inference includes VAD/chunking/retries, so compare it
separately from the native probe. Metrics omit transcript text.

Next: retain a proven CPU path while evaluating GPU capability/error handling,
minimum-API compatibility, sustained timings, and broader audio evidence. Keep
device/backend policy outside text-processing logic so Windows/Linux can supply
their own supported execution paths.
