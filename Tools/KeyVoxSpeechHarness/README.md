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
module is selected by destination platform, not the build host. Its regular C
target also lets Xcode resolve the dependency graph when building Apple apps.

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
| Whisper / GGML CPU libraries | FUNCTIONAL | NDK arm64-v8a API 28 build executed on an SM-S948U1 device |
| KeyVoxWhisper wrapper | FUNCTIONAL | Real tiny.en model produced a transcript through the Swift wrapper |
| Silero VAD wrapper and resource | FUNCTIONAL | Silence: 32 probabilities, no speech; spoken audio: 344 probabilities, five speech segments |
| Speech harness | FUNCTIONAL | Executed both commands on the connected Android device |
| Android speech inference / VAD execution | FUNCTIONAL | Public upstream JFK fixture: 176,000 samples, two transcript segments |
| Portable WAV/sample loading | COMPILING | Android compiled the new audio sources; generated PCM and resampling fixtures pass on macOS; device execution pending |
| Core package graph | COMPILING | Full Android build with static Swift standard library and real Whisper native dependencies passes |
| Core text processing execution | UNRESOLVED | Runtime harness integration pending; linguistic features remain incomplete |
| Date/address numeric protection | STUBBED | Semantic availability is explicit; non-Apple prose is conservatively preserved |

There are no placeholder inference implementations. Compilation is not execution
evidence. After correcting Xcode's conditional-target graph failure, the final
Android executable was rebuilt and Whisper/VAD execution repeated successfully.
Local Xcode validation: 381 iOS app tests and 401 macOS app tests passed. All ten
package suites passed; LocalInference retained nine model-dependent skips.

The Android speech fixture was `samples/jfk.wav` from Whisper v1.7.6, converted
from mono 16 kHz signed PCM16 to float32. Model: `ggml-tiny.en.bin` from
`ggerganov/whisper.cpp` on Hugging Face. Observed output:

> And so my fellow Americans ask not what your country can do for you ask what you can do for your country.

This proves file-based inference, not microphone capture or Core processing.
The model's automatic language metadata reported an unexpected language for this
English-only model; transcript generation succeeded, but language metadata needs
separate investigation before relying on it.

Core's audio-file capability retains the existing Apple converter. Its portable
implementation supports little-endian RIFF/WAVE integer PCM (8/16/24/32-bit) and
float32, equal-weight channel mixing, and windowed-sinc conversion to mono 16 kHz.
Supported source rates are 8–384 kHz; compressed audio and WAVE extensible require
another decoder and currently fail explicitly. Malformed chunks and nonfinite
samples are rejected. Generated fixtures cover decoding, malformed input,
channel mixing, rate conversion, and alias suppression. No third-party code or
recordings were introduced for this capability. The same implementation is
available to future Windows and Linux hosts.

Date/address spans now have a semantic capability boundary. Apple retains its
detectors. On other platforms, unavailable detection permits only isolated
numeric-line candidates after existing structural protections; prose remains
unchanged. Standalone values in the plausible-year range still depend on lexical
analysis and may remain unchanged. This is a temporary limitation, not portable
date/address recognition. Float audio RMS uses Swift's native square-root
operation, retaining its original precision without platform-specific overloads.

The existing `VoiceActivityAnalyzing` semantic boundary remains intact. The
Whisper C packaging boundary can also accept Linux/Windows native libraries;
the script's `native` mode uses the host CMake toolchain. Those destinations are
not yet validated, and Windows tooling/linking still needs its own verification.
Non-Apple builds use CPU inference; GPU integration remains future work.
