# Portable speech harness

This command-line host exercises real KeyVox Whisper, optional native Parakeet,
Silero VAD, and Core processing. It makes no
frontend decision. Input is mono, 16 kHz, little-endian float32 PCM with samples
in [-1, 1]. Convert an audio fixture using:

```sh
ffmpeg -i input.wav -ar 16000 -ac 1 -f f32le audio.f32le
```

## Android build

For repeated service/Core timing, use
`benchmark-file-pipeline <model.bin> <audio-file> <repeats>` with 1–10 repetitions.
It reports model/VAD warmup, text/dictionary preparation, provider execution, and
Core processing separately, and rejects inconsistent repeated output. Reports
contain private transcript text; keep raw logs outside the repository.

To exercise the optional Vulkan build, use its separate Whisper prefix and add
`-Xlinker -lggml-vulkan -Xlinker -lvulkan` to the build below. The tested GPU
runs FP16 with the builder's Adreno matrix-routing backport;
`GGML_VK_DISABLE_F16=1` provides the FP32 control and
`GGML_VK_VISIBLE_DEVICES=''` exercises CPU fallback.
Confirm actual backend activation in native logs. See the
[performance record](../../Docs/Android/PERFORMANCE.md) for evidence and limitations.

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

Include `Tools/Licenses/SwiftCrypto` with distributions of the model integrity
capability, alongside the existing SDK/NDK and native runtime notices. Copy all
SwiftPM-generated resource directories beside the diagnostic executable; the
cross-compiled Crypto targets also emit privacy resources. See the exact source
and measured native linkage record in `Tools/Licenses/SwiftCrypto`.

This combined diagnostic executable also links `libparakeet.so`; deploy it with
the installed `share/licenses/keyvox-parakeet` notices. Core and the shipping Apple
apps do not acquire this dependency. Its GGML symbols remain private to that library.

```sh
./KeyVoxSpeechHarness whisper-model
./KeyVoxSpeechHarness probe-model-recovery ggml-base.bin invalid-model.bin speech.wav
./KeyVoxSpeechHarness probe-base-download /path/to/download-check
./KeyVoxSpeechHarness vad audio.f32le
./KeyVoxSpeechHarness transcribe ggml-base.bin audio.f32le
./KeyVoxSpeechHarness pipeline model.bin audio.f32le
./KeyVoxSpeechHarness file-pipeline ggml-base.bin audio.wav
./KeyVoxSpeechHarness parakeet-file-pipeline model.gguf audio.wav
./KeyVoxSpeechHarness process input.txt
./KeyVoxSpeechHarness dictionary-add /path/to/diagnostic-storage phrase.txt
```

`whisper-model` prints the shared Base filename, pinned URL/revision, and SHA-256
for host download/integrity checks. Apple catalogs use this same definition.
It performs no download and does not select or change an installed model.

`probe-base-download` exercises a foreground `URLSession` transfer of that exact
Base artifact into a dedicated diagnostic directory. `KeyVoxModels` streams the
temporary file through SHA-256 and checks the shared pinned digest before moving
it to the destination. The report includes actual and expected digests and
`integrityVerified: true` only after a match. Mismatch fails without publishing the
file. It refuses an already existing destination; use a dedicated directory
without concurrent writers. This proves foreground transfer and integrity, not
complete model installation, resumability, background transfer, or onboarding.

`probe-model-recovery` exercises the existing shared service using caller-supplied
speech audio, a verified Base model, and a separate invalid diagnostic model file
(the measured fixture contains four zero bytes). It does not write or delete any
of these files. It tries an absent model selection, the invalid file, then Base,
then unloads and reloads Base again. Each stage reports file availability, result
presence, nonempty speech, and processing state. A failed expectation exits
nonzero. Supply known speech, not silence, for the recovery checks.

The device run rejected the invalid model and produced speech after both recovery
and reload. An absent selection currently produces an empty result; the invalid
file produces a failure result. `WhisperService.isModelReady` checks file existence,
so it is reported as `fileAvailable` here and is true even for the invalid file.
This is service lifecycle evidence, not verified installation or checksum checking.
Preserve the existing iOS install owner's integrity checks when connecting Android
model management. No inference settings or automatic language selection change.

On Android, the harness links the official SDK's existing SSL/crypto archives and
OS-provided zlib for FoundationNetworking. Preserve the full notices in
`Tools/Licenses/Swift-Android`, including BoringSSL's acknowledgments and conditions.
Apple continues using its existing Foundation networking implementation.

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

Set `KEYVOX_LINGUISTIC_MODEL` to the averaged-perceptron directory and
`KEYVOX_LEXICAL_DATABASE` to the WordNet 3.0 directory to select the same portable
combination as the Android engine. See both model directories for exact licenses,
provenance, supported language, hashes, and distribution obligations. Reports
include the implementation identity, token ranges, and semantic roles. Apple
retains its existing analyzer. An explicit unsupported language receives Unicode
boundaries and unavailable semantic features. A caller that selects no language
may provide its own documented host default, as Android does for English.

## Engineering record

| Capability | Android status | Evidence |
| --- | --- | --- |
| Whisper / GGML CPU libraries | FUNCTIONAL | NDK arm64-v8a API 28 build executed on an SM-S948U1 device |
| KeyVoxWhisper wrapper | FUNCTIONAL | Exact iOS Base weights executed through the shared production service on Android |
| Optional native Parakeet / Swift backend / Core service | FUNCTIONAL | Actual 5.6-second phone microphone WAV passed through shared decoding, VAD, ParakeetService, native inference, and Core; host supplied processing language |
| Silero VAD wrapper and resource | FUNCTIONAL | Silence: 32 probabilities, no speech; spoken audio: 344 probabilities, five speech segments |
| Speech harness | FUNCTIONAL | Executed both commands on the connected Android device |
| Android speech inference / VAD execution | FUNCTIONAL | Public upstream JFK fixture: 176,000 samples, two transcript segments |
| Portable WAV/sample loading | FUNCTIONAL | Android production service decoded mono 16 kHz speech and stereo 48 kHz speech; 48 kHz stereo silence produced empty output; malformed WAV failed |
| Core package graph | FUNCTIONAL | Clean Android build and the recorded 582-test shared Core bakeoff executed successfully on Android |
| Core text processing execution | FUNCTIONAL | Real NPU Whisper transcript passed through production Core with the selected perceptron and WordNet capabilities |
| Dictionary persistence and Core connection | FUNCTIONAL | Android/macOS separate-process canonical output matched; duplicate rejection preserved entries; backup recovery and pre-mutation warnings verified; speech pipeline loaded persisted entries |
| Spanish/French Core text fixtures | FUNCTIONAL | Existing spoken-list fixtures produced identical formatted output on Android and macOS; no optional grammatical-role model selected |
| iOS Whisper Base model and service | FUNCTIONAL | Exact iOS GGML artifact checksum matched; existing microphone recording passed through shared service/VAD/Core with automatic language metadata and persisted dictionary correction |
| Foreground Base download transport | FUNCTIONAL | Android Swift download now verifies exact Base internally before publishing it, then runs real VAD/inference/Core; independent device checksum matched; earlier Apple transport and external-checksum evidence remains applicable |
| Unicode word boundaries | FUNCTIONAL | Real transcript yielded matching UTF-16 token ranges on Android and macOS |
| Portable grammatical roles | FUNCTIONAL | Focused perceptron and WordNet provider passes all shared Core expectations; Android logs the exact selected implementation |
| Portable names / lemmas | FUNCTIONAL | Name identity and noun inflection cover Core's consumed behavior. General lemmas remain explicitly unavailable; Apple retains native lemmas |
| Android microphone host | FUNCTIONAL | Real phone recording: 89,600 samples, 73,600 VAD-selected samples, speech inference and Core processing executed; adb orchestrates the WAV handoff |
| Date/address numeric protection | FUNCTIONAL | Portable semantic protection matches all shared date, address, year, and quantity expectations |

There are no placeholder inference implementations. Compilation is not execution
evidence. The recorded final Android executable passed 582 / 582 Core tests, and the
protected NPU application repeated real Whisper/VAD/Core execution successfully.
Local Xcode validation: 381 iOS app tests and 401 macOS app tests passed. All ten
package suites passed; LocalInference retained nine model-dependent skips.

Multilingual text evidence reuses the existing first-party
`testDetectsSpanishSpokenMarkers` and `testDetectsFrenchSpokenMarkers` inputs from
Core's `ListPatternDetectorTests`. Both full processing runs produced the same
three-item lists as macOS. This establishes those formatting scenarios, not general
language or NLP parity. No fixture vocabulary was added to the engine.

The Android baseline is the existing iOS **Whisper Base** model, `ggml-base.bin`,
from revision `90a64d80ea254cf67575b41a5971f972c79f7b45`. Its 147,951,465 bytes
match iOS's SHA-256 `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`.
These existing iOS values now live in `KeyVoxModels.WhisperBaseModelArtifact`, consumed
by the Apple catalogs and available to Android; the license lock records that
existing artifact. Apple-specific accelerator assets and install flows remain
owned by their existing app catalogs.
The model is MIT-licensed, with the retained OpenAI notice and pinned model-card
license declaration recorded in `Tools/Licenses/runtime-models.lock.json`.

Using `file-pipeline`, the existing 5.6-second microphone recording passed through
production `WhisperService`, Silero VAD, Base inference, and Core. Automatic
language metadata reached Core without an override, and the existing persisted
dictionary corrected the recognized name. The existing 48 kHz silence fixture
returned empty output. These checks use shared service parameters, not new
Android decoding settings. Bare `transcribe`/`pipeline` commands are lower-level
probes and do not establish iOS service-configuration parity.

Android uses the same GGML weights on CPU or the optional Vulkan backend.
iOS additionally installs its cataloged
Core ML Base encoder; accelerator execution is platform-specific. Supported
language selection remains owned by `WhisperBaseLanguageCatalog` and
`WhisperService.updateLanguage`. The harness's final language argument only selects
text processing; it does not exercise the iOS language-selection flow.
Cross-language recognition accuracy is outside this experiment.

The optional native Parakeet result demonstrates a backend capability, not exact
iOS model parity: its experimental GGUF Q8 weights differ from iOS's cataloged
Core ML EncoderInt4 artifacts. It is not an Android product model selection.

Earlier Tiny runs below are historical runtime checks, not the product baseline.
The Android speech fixture was `samples/jfk.wav` from Whisper v1.7.6, converted
from mono 16 kHz signed PCM16 to float32. Model: `ggml-tiny.en.bin` from
`ggerganov/whisper.cpp` on Hugging Face. Observed output:

> And so my fellow Americans ask not what your country can do for you ask what you can do for your country.

The initial `pipeline` command subsequently passed this actual inferred text
through Core on the same phone and produced the transcript with its leading
whitespace removed. Its historical JSON report showed all four linguistic
features unavailable. A later diagnostic verified the Swift predictor matched
the pinned upstream Python implementation on all 23 context tokens. The final
Android host now combines that predictor with focused contextual resolution and
WordNet lexical evidence; the recorded 582-test cross-platform bakeoff passed and
the production NPU path logs that exact provider. This establishes measured Core text behavior, not
general linguistic accuracy outside Core's consumed semantics.
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

Date/address spans retain their semantic capability boundary. Apple continues to
use its native detectors. Android supplies focused portable numeric protection
for the date, address, year, and quantity decisions Core consumes, including an
explicit conservative missing-language fallback. Float audio RMS uses Swift's
native square-root operation, retaining its original precision without
platform-specific overloads.

The existing `VoiceActivityAnalyzing` semantic boundary remains intact. The
Whisper C packaging boundary can also accept Linux/Windows native libraries;
the script's `native` mode uses the host CMake toolchain. Those destinations are
not yet validated, and Windows tooling/linking still needs its own verification.
CPU remains the default non-Apple build. The optional Vulkan build executes on
Android; Windows/Linux acceleration and Android app GPU integration remain unverified.
