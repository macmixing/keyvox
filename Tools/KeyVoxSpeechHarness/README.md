# Portable speech harness

This command-line host exercises real KeyVox Whisper, optional native Parakeet,
Silero VAD, and Core processing. It makes no
frontend decision. Input is mono, 16 kHz, little-endian float32 PCM with samples
in [-1, 1]. Convert an audio fixture using:

```sh
ffmpeg -i input.wav -ar 16000 -ac 1 -f f32le audio.f32le
```

## Android build

From the repository root, set `ANDROID_NDK_ROOT` to the installed NDK, then:

```sh
bash Tools/build-portable-whisper.sh android /tmp/keyvox-whisper-android
bash Tools/ParakeetNative/build-android.sh /tmp/keyvox-parakeet-android
cd Tools/KeyVoxSpeechHarness
swift build \
  --swift-sdk aarch64-unknown-linux-android28 \
  --static-swift-stdlib \
  --scratch-path /tmp/keyvox-port-speech-harness-android \
  -Xcc -I/tmp/keyvox-whisper-android/include \
  -Xcc -I/tmp/keyvox-parakeet-android/include \
  -Xlinker -L/tmp/keyvox-whisper-android/lib \
  -Xlinker -L/tmp/keyvox-parakeet-android/lib \
  -Xlinker -lc++_shared
```

The script verifies the v1.7.6 source archive SHA-256 and builds static Whisper
and GGML CPU libraries. Apple retains the existing v1.7.6 XCFramework. The C
module is selected by destination platform, not the build host. Its regular C
target also lets Xcode resolve the dependency graph when building Apple apps.

Deploy the executable, `KeyVoxVoiceActivity_KeyVoxVoiceActivity.resources`, and
`KeyVoxCore_KeyVoxCore.resources` and `KeyVoxLinguistics_KeyVoxLinguistics.resources`
directories from the Android build output together.
Preserve the bundled resource notices. Also deploy `libc++_shared.so`
from the NDK's `toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android`
directory and put its location on `LD_LIBRARY_PATH`. The Swift standard library
is linked statically. Any additional runtime dependencies must be verified on
the execution target.

This combined diagnostic executable also links `libparakeet.so`; deploy it with
the installed `share/licenses/keyvox-parakeet` notices. Core and the shipping Apple
apps do not acquire this dependency. Its GGML symbols remain private to that library.

```sh
./KeyVoxSpeechHarness vad audio.f32le
./KeyVoxSpeechHarness transcribe ggml-tiny.en.bin audio.f32le
./KeyVoxSpeechHarness pipeline model.bin audio.f32le
./KeyVoxSpeechHarness file-pipeline model.bin audio.wav
./KeyVoxSpeechHarness parakeet-file-pipeline model.gguf audio.wav
./KeyVoxSpeechHarness process input.txt
./KeyVoxSpeechHarness dictionary-add /path/to/diagnostic-storage phrase.txt
```

`pipeline` feeds actual Whisper segments to `TranscriptionPostProcessor`.
`process` accepts a UTF-8 text file. Both emit a JSON
report containing input, output, processing language, and available linguistic
features. An optional final language-code argument selects the processing
language; it does not change speech inference. Without it, `pipeline` forwards
detected metadata, including any model metadata anomaly. The harness does not
change model installation state. With no dictionary directory selected, processing
uses an empty dictionary and does not open dictionary storage.

Set `KEYVOX_DICTIONARY_DIRECTORY` to explicitly select a diagnostic DictionaryStore
base directory for any processing command. `dictionary-add` reads one phrase from
the supplied UTF-8 file and saves through the existing store. It prints snapshots
before and after the mutation, including load/save warnings and degraded durability;
failure exits nonzero. Processing reports the loaded entry count and the same
diagnostics. The selected directory uses normal store recovery behavior: loading
can restore a backup or quarantine damaged data. It is not a read-only import.
Use a dedicated diagnostic directory. The existing pronunciation resources and
dictionary correction rules are unchanged.

`file-pipeline` uses the production `WhisperService` file path: platform audio
decoding, Silero VAD, speech-range selection, Whisper inference, then Core text
processing. Android accepts the portable WAV formats below; Apple uses its
existing audio converter. Its optional final language-code argument selects text
processing only. A missing model or failed decode/transcription exits with an
error; detected silence succeeds with empty output.

`parakeet-file-pipeline` uses the same shared audio decoder, ParakeetService/VAD,
the optional native backend, and Core. An optional final processing-language
argument supplies host knowledge; the native backend reports no detected language.
See `Packages/KeyVoxParakeetNative/README.md` for lifecycle and metadata limitations
and `Tools/ParakeetNative/README.md` for native/model provenance and licenses.

Set `KEYVOX_LINGUISTIC_MODEL` to an external model directory to explicitly select
the optional statistical analyzer. See `Tools/Models/averaged-perceptron-tagger-eng`
for its MIT license, provenance, supported language, and accuracy limitations.
Reports include token ranges and semantic roles for inspection. The default
non-Apple analyzer provides Unicode word boundaries without grammatical roles;
Apple retains its existing analyzer. Neither analyzer selection introduces a
shared engine language default. Preserve the bundled `PERCEPTRON-LICENSE.txt`
when distributing the predictor, and the model's `LICENSE.txt` when including
its optional assets.

## Engineering record

| Capability | Android status | Evidence |
| --- | --- | --- |
| Whisper / GGML CPU libraries | FUNCTIONAL | NDK arm64-v8a API 28 build executed on an SM-S948U1 device |
| KeyVoxWhisper wrapper | FUNCTIONAL | Real tiny.en model produced a transcript through the Swift wrapper |
| Optional native Parakeet / Swift backend / Core service | FUNCTIONAL | Actual 5.6-second phone microphone WAV passed through shared decoding, VAD, ParakeetService, native inference, and Core; host supplied processing language |
| Silero VAD wrapper and resource | FUNCTIONAL | Silence: 32 probabilities, no speech; spoken audio: 344 probabilities, five speech segments |
| Speech harness | FUNCTIONAL | Executed both commands on the connected Android device |
| Android speech inference / VAD execution | FUNCTIONAL | Public upstream JFK fixture: 176,000 samples, two transcript segments |
| Portable WAV/sample loading | FUNCTIONAL | Android production service decoded mono 16 kHz speech and stereo 48 kHz speech; 48 kHz stereo silence produced empty output; malformed WAV failed |
| Core package graph | COMPILING | Full Android build with static Swift standard library and real Whisper native dependencies passes |
| Core text processing execution | FUNCTIONAL | Real Whisper transcript passed through production Core on the Android phone; linguistic features remain incomplete |
| Dictionary persistence and Core connection | FUNCTIONAL | Android/macOS separate-process canonical output matched; duplicate rejection preserved entries; backup recovery and pre-mutation warnings verified; speech pipeline loaded persisted entries |
| Unicode word boundaries | FUNCTIONAL | Real transcript yielded matching UTF-16 token ranges on Android and macOS |
| Optional statistical grammatical roles | FUNCTIONAL | Explicitly selected MIT model: 22 word tokens, 20 supported roles; Android/macOS reports identical; pinned reference predictor matched all 23 context tokens |
| Portable names / lemmas | UNRESOLVED | Optional predictor reports both unavailable; Apple implementation remains available |
| Android microphone host | FUNCTIONAL | Real phone recording: 89,600 samples, 73,600 VAD-selected samples, speech inference and Core processing executed; adb orchestrates the WAV handoff |
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

The `pipeline` command subsequently passed this actual inferred text through
Core on the same phone and produced the transcript with its leading whitespace
removed. This proves execution of the real processing path, not linguistic
parity: the JSON report explicitly showed all four linguistic features unavailable.
The later Unicode boundary implementation and explicitly selected optional
perceptron model provide real boundaries and partial grammatical roles. On the
same transcript, Android and macOS produced identical token ranges, supported
roles, and processed output. A diagnostic compared the Swift predictor with the
pinned upstream Python implementation using identical tokens; all 23 predictions
matched. Tokenization and sentence-context limitations remain as documented with
the model. This does not establish general linguistic accuracy or Apple parity.
The separate capture host produced a real microphone WAV for `file-pipeline`:
5.6 seconds of audio yielded a transcript through the actual VAD, WhisperService,
and Core path on the phone. This uses an adb-orchestrated file handoff, without an
in-app Swift bridge or frontend decision. Its README records hardware evidence
and lifecycle checks. The recording is not incorporated into the repository.
The initial monolingual run exposed invalid automatic language metadata in the
pinned Whisper runtime. The native adapter now uses that model family's fixed
runtime language and disables unsupported detection on request-local parameters.
Multilingual requests retain their existing behavior. A subsequent Android
`file-pipeline` run reported the correct model language and enabled the optional
grammatical model without a processing-language override. No language literal or
default was added to the shared engine.

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
