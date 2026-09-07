# Portable speech harness

This command-line host exercises real KeyVox Whisper and Silero VAD. It makes no
frontend decision. Input is mono, 16 kHz, little-endian float32 PCM with samples
in [-1, 1]. Convert an audio fixture using:

```sh
ffmpeg -i input.wav -ar 16000 -ac 1 -f f32le audio.f32le
```

## Android build

From the repository root, set `ANDROID_NDK_ROOT` to the installed NDK, then:

```sh
bash Tools/build-portable-whisper.sh android /tmp/keyvox-whisper-android
cd Tools/KeyVoxSpeechHarness
swift build \
  --swift-sdk aarch64-unknown-linux-android28 \
  --static-swift-stdlib \
  --scratch-path /tmp/keyvox-port-speech-harness-android \
  -Xcc -I/tmp/keyvox-whisper-android/include \
  -Xlinker -L/tmp/keyvox-whisper-android/lib \
  -Xlinker -lc++_shared
```

The script verifies the v1.7.6 source archive SHA-256 and builds static Whisper
and GGML CPU libraries. Apple retains the existing v1.7.6 XCFramework. The C
module is selected by destination platform, not the build host. The optional
pkg-config lookup can warn when using explicit include/link flags as above.

Deploy the executable and `KeyVoxVoiceActivity_KeyVoxVoiceActivity.resources`
directory from the Android build output together. Also deploy `libc++_shared.so`
from the NDK's `toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android`
directory and put its location on `LD_LIBRARY_PATH`. The Swift standard library
is linked statically. Any additional runtime dependencies must be verified on
the execution target.

```sh
./KeyVoxSpeechHarness vad audio.f32le
./KeyVoxSpeechHarness transcribe ggml-tiny.en.bin audio.f32le
```

## Engineering record

| Capability | Android status | Evidence |
| --- | --- | --- |
| Whisper / GGML CPU libraries | COMPILING | NDK arm64-v8a API 28 build and install succeeded |
| KeyVoxWhisper wrapper | COMPILING | Swift 6.3.3 Android build succeeded |
| Silero VAD wrapper and resource | COMPILING | Included in linked Android harness |
| Speech harness | COMPILING | Real native libraries linked successfully |
| Android speech inference / VAD execution | UNRESOLVED | No device or emulator configured at initial validation |
| Core text processing | UNRESOLVED | Apple framework dependencies still need portability work |

There are no placeholder inference implementations. Compilation is not execution
evidence. macOS Whisper regression suite: 22 tests passed using Xcode Swift.

The existing `VoiceActivityAnalyzing` semantic boundary remains intact. The
Whisper C packaging boundary can also accept Linux/Windows native libraries;
the script's `native` mode uses the host CMake toolchain. Those destinations are
not yet validated, and Windows tooling/linking still needs its own verification.
Non-Apple builds use CPU inference; GPU integration remains future work.
