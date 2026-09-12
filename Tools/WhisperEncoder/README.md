# Optional native Whisper encoders

This boundary replaces encoding and cross-attention cache preparation while
retaining Whisper's existing tokenizer, language detection, decoding, timestamps,
segment handling, and CPU implementation. It does not own models or downloads.

`build-portable-whisper.sh` applies the first-party extension to pinned Whisper
1.7.6. The Apple XCFramework is unchanged. Hosts can supply a
`WhisperEncoderConfiguration` when constructing `Whisper`, including through
`WhisperService`'s factory. Without configuration, existing behavior is retained.
Older native builds without the extension also retain normal inference.

The C ABI is in `include/keyvox-whisper-encoder.h`. A native plugin exports
`keyvox_whisper_encoder_create_v1`; it must validate model compatibility and
provide the documented cache layout. The host must verify the paired model
artifacts before configuration. Plugin and runtime paths refer to installed,
trusted native code, not downloaded executable content.

Each Whisper context owns its plugin instance. Calls are serialized even through
Whisper's parallel native entry point. Cancellation is checked before execution
and before publishing caches. Initialization failure retains the native encoder;
an execution failure disables the plugin for that context and retries encoding
through the existing implementation. This does not recover native process crashes.

Flash-attention and explicitly shortened audio contexts use the existing encoder.
`isExternalEncoderConfigured` reports successful initial attachment, not a promise
that every later request uses the plugin.

The native fixtures cover missing plugins, rejected initialization, successful
encoding, cancellation, execution failure, destruction and concurrent calls.
Compile `Tests/FixturePlugin.cpp` as a shared library, and compile
`Tests/ExternalEncoderTests.cpp` with `ExternalEncoder.cpp`; pass the fixture
library's absolute path to the test executable. Both require C++17 and include
paths for this directory and `include`. Linux/Android link `libdl`.

All extension and fixture code is MIT. The patched upstream runtime remains MIT
and its existing notices are retained by the builder. No accelerator runtime,
model, tokenizer, or other third-party asset is bundled by this boundary.
