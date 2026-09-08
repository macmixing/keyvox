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
| Vulkan, original default FP16 | Device-lost exception; addressed by the backport below |
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
- GPU is FUNCTIONAL in the native probe and real Swift service/VAD/Core diagnostic
  pipeline in FP32 and patched FP16 modes on this device. Selection based on measured performance,
  driver-error recovery, other devices, and installed GPU app integration remain
  UNRESOLVED. A device-lost crash is not a working CPU fallback.
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

## Shared Swift service checkpoint

The wrapper previously disabled GPU for every non-Apple platform, including a
Vulkan-linked runtime. `WhisperComputePolicy.automatic` now allows the native
runtime to select available acceleration outside Apple and retries context
initialization once with GPU disabled if GPU initialization returns failure.
`.gpuDisabled` explicitly selects the CPU backend. It does not disable independent
Apple model accelerators such as Core ML. Existing iOS Metal restrictions and
macOS Ventura initialization behavior remain intact.

With `GGML_VK_DISABLE_F16=1`, native logs confirm Base weights in Vulkan buffers
and selection of the Vulkan backend through the real `WhisperService`. Silero VAD
remains on CPU. Hiding GPU devices exercises the same executable through CPU.
Both complete `file-pipeline` reports matched, including processed output and
language metadata. These fresh-process runs took about 5.6 seconds including
startup; they are not evidence of lower cold latency.

The repeated `benchmark-file-pipeline` probe separates preparation and processing:

| Stage | GPU | CPU fallback |
| --- | --- | --- |
| Model/VAD warmup | 340 ms | 102 ms |
| Text processor/dictionary preparation | 2,833 ms | 2,779 ms |
| First provider call | 2,511 ms | 2,475 ms |
| Subsequent provider calls | 2,024–2,027 ms | 2,539–2,547 ms |
| Core processing per result | 11–22 ms | 5–7 ms |

All six outputs matched exactly. Provider timing includes file decoding, VAD,
chunking, and speech inference. Preparation is reported separately, not removed
from the total cost. These are diagnostic-host measurements, not keyboard latency.
Whisper package assertions passed on Apple (29) and Android (28), including
platform-specific initialization and explicit GPU-disabled coverage.

## FP16 failure investigation and upstream backport

Measured September 8, 2026 (America/Phoenix), on the same device, model, audio,
and automatic language setting. Default FP16 failed even with one operation per
submission. Synchronized diagnostics observed failures in both large FP16/FP16
and FP16/FP32 matrix kernels; the first failing operation varied across runs.
Changing only FP16/FP16 accumulation to FP32 did not prevent the other variant
from failing. Forcing medium or small tiles completed all three diagnostic runs
per variant. These overrides remain outside the repository runtime.

Upstream [llama.cpp PR #24877](https://github.com/ggml-org/llama.cpp/pull/24877)
reports the same device-lost symptom on Adreno 840 and contains an approved,
merged workaround routing large matrix operations to medium tiles. Its exact
commit `76f2798059575a96a12e4d34342165a4b6a6a312` is backported by the optional
Vulkan builder; the only adaptation adds the existing upstream Qualcomm vendor
identifier. Small tiles and later shared-memory capability checks are retained.
The driver/compiler root cause is not established; insufficient shared memory is
not a proven explanation.

The pinned upstream license is MIT, Copyright (c) 2023–2026 The ggml authors.
The complete notice and provenance are retained in
`Tools/Licenses/Whisper-Vulkan-Backport-NOTICES.txt` and the installed native
prefix. Android's existing notice staging copies this source notice directory.
The upstream commit changes only matrix routing; no additional dependencies,
models, shader assets, or generated data are adopted. Independent license review
verified the actual pinned license and one-file patch.

Clean packaged runtime, with no diagnostic overrides:

| Backend | First call | Warm calls |
| --- | --- | --- |
| Patched FP16, 10 runs | 2.410 s | 1.977–1.992 s |
| CPU, 3 runs | 2.346 s | 2.402–2.508 s |
| No-visible-GPU fallback, 3 runs | 2.572 s | 2.521–2.557 s |
| FP32 control, 3 runs | 2.437 s | 2.004–2.007 s |

All 19 native outputs matched. The real Swift service/VAD/Core pipeline also
completed three FP16 runs with identical processed output: provider 2.505 s first,
2.019–2.021 s warm; Core 12–24 ms. Model/VAD warmup was 360 ms and text preparation
2.751 s, reported separately. API 28 linking and clean source build passed.

This fixes the observed FP16 crash in these trials, but provides no material
additional speedup over FP32. It does not prove general driver reliability,
other-device behavior, sustained thermal performance, or installed keyboard GPU
latency. The installed app continues using CPU while GPU selection and recovery
remain under investigation.

Related upstream reports were checked: [#8743](https://github.com/ggml-org/llama.cpp/issues/8743)
and [#12139](https://github.com/ggml-org/llama.cpp/issues/12139) describe older Adreno
device-lost failures but closed as stale without a fix. The distinct
[subgroup-size-128 issue](https://github.com/ggml-org/llama.cpp/issues/25734) does
not match this device's reported subgroup size of 64. The
[Whisper Adreno 830 report](https://github.com/ggml-org/whisper.cpp/issues/3551)
describes a pipeline-binding crash rather than our measured execution failure.

## Installed Qualcomm encoder implementation — 2026-09-08

The optional first-party native plugin in `Native/WhisperQNN` now runs inside the
real Android shell. It replaces only the encoder computation; multilingual Base,
the original Whisper decoder, automatic language handling, VAD, and Core remain
in the real pipeline. Host-owned installation checks archive and encoder hashes
and uses the existing download action. Base remains usable without this asset.

On SM8850, three final installed-app runs with the same private fixture and a
4-second preparation lead-in produced identical processed-output SHA-256 values
between NPU and CPU fallback:

| Path | Provider inference | Pipeline including Core | Initial model warmup |
| --- | --- | --- | --- |
| Qualcomm encoder | 438 / 421 / 388 ms | 455 / 436 / 402 ms | 315 ms |
| CPU fallback, optional encoder absent | 2394 / 2458 / 2489 ms | 2412 / 2474 / 2505 ms | 102 ms |

Native Android log records independently confirm successful NPU execution. Each
Whisper request may encode more than once. Setup cost is separate from inference;
an immediate-start run still waited 1.94 seconds for existing Core preparation.
The speedup does not eliminate that cold text-preparation cost.

The actual app downloaded and verified the encoder before inference. Optional
download/retry availability is separate from Base readiness. Missing acceleration
assets retain CPU operation, and the test restored the installed encoder afterward.
Native checks cover invalid configuration, mismatched tensor shapes, cancellation,
repeated construction/destruction, cache layout/scaling, and nonfinite rejection.
Cancellation cannot interrupt an already-running synchronous QNN graph call.

Debug/release APKs and lint pass locally (release packaging used a 4 GiB Gradle
heap). Only the validated SM8850 artifact is selected today; the runtime boundary
is not tied to a phone identifier. Other targets retain native inference until
their corresponding artifacts are validated. Sustained thermal behavior, broader
audio accuracy, and other Qualcomm generations are not established.

The SDK binary closure is pinned in `Native/WhisperQNN/runtime.lock.json`.
[Artifact and license provenance](../../Tools/Licenses/Whisper-QNN/PROVENANCE.md)
records the remaining SDK component/source-obligation evidence gap. Local device
success does not establish redistribution clearance.

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
