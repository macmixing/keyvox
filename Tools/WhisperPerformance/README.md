# Whisper performance probe

This command measures the native runtime separately from VAD, Core processing,
and the Android host. It consumes caller-provided mono 16 kHz little-endian
Float32 PCM. Audio and model weights are not included.

Build the CPU runtime with `../build-portable-whisper.sh`, then compile against
that prefix using the installed Android NDK:

```sh
"$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android28-clang++" \
  -O3 -std=c++17 -I"$WHISPER_PREFIX/include" benchmark.cpp \
  -Wl,--start-group "$WHISPER_PREFIX/lib/libwhisper.a" \
  "$WHISPER_PREFIX/lib/libggml.a" "$WHISPER_PREFIX/lib/libggml-base.a" \
  "$WHISPER_PREFIX/lib/libggml-cpu.a" -Wl,--end-group -llog \
  -o /tmp/keyvox-whisper-benchmark
```

Deploy that executable and its NDK libc++ runtime with adb. Invoke it on device:

```sh
LD_LIBRARY_PATH="$RUNTIME_DIRECTORY" "$BENCHMARK" \
  "$MODEL" "$PCM_FILE" "$THREADS" "$REQUEST_GPU" "$REPEATS" "$LANGUAGE"
```

`REQUEST_GPU` is 0 or 1. A CPU-only build cannot accelerate even when GPU is
requested. Verify actual backend initialization in native stderr, not this flag.
`LANGUAGE` is the caller's Whisper language code or its `auto` detection mode;
there is no selected-language default. Use the shared iOS Base artifact for parity.
The probe uses the service's greedy/no-context decoding settings, without its
VAD/chunking or downstream processing. It does not prove application latency.

`KV_LOAD` reports context creation. `KV_RUN total_ms` reports each complete native
decode; the individual timing fields are native **per-call averages**, not stages
that can be summed. Native stderr includes call counts and cumulative times.
`KV_TEXT` contains private recording content; keep raw logs outside the repository.

See [Android measurements](../../Docs/Android/PERFORMANCE.md) for current evidence
and GPU limitations. This tool introduces no new runtime dependency.

## Optional Vulkan runtime

The existing builder accepts an explicit third argument while retaining its CPU
default. Use a separate prefix for each backend:

```sh
../build-portable-whisper.sh android "$WHISPER_VULKAN_PREFIX" vulkan
```

This downloads checksum-pinned Vulkan-Headers (Apache-2.0 selected), retains CPU,
builds shaders with the installed NDK compiler, and stages complete notices.
Its small query-reset patch uses Vulkan's command-buffer operation, allowing
linkage against Android API 28 without removing optional timestamp diagnostics.
Apple XCFramework packaging is unaffected.

Compile the probe as above against this prefix, adding `libggml-vulkan.a` inside
the linker group and `-lvulkan` after it. GPU request 0 still selects CPU.
The builder includes the MIT-licensed upstream Adreno matrix-routing backport;
FP16 passes on the tested device. Use `GGML_VK_DISABLE_F16=1` for an FP32 control.
Setting `GGML_VK_VISIBLE_DEVICES=''` exercises absent-GPU CPU fallback
even with request 1. This does not simulate a mid-inference driver failure.

The Android app's standard engine staging remains CPU-only. This optional build
is not an automatic backend selection policy or a promise that GPU will be faster
on another device. See the performance record before adopting it into a host.
