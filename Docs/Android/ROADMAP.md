# Android dictation parity roadmap

## Destination and current scope

Bring KeyVox's existing iOS dictation behavior to Android, preserving the shared
engine and leaving clean capability boundaries for Windows and Linux. TTS and
Vibes are outside this phase; retain extension points for later work.

Current work is package portability and real engine execution. The capture APK
is a diagnostic host, not the future app or a frontend architecture decision.
Production UI, onboarding, billing, and keyboard UX come later. Native platform
presentation remains free to use whichever technology best supports the app.

The first real Android microphone recording has already passed through VAD,
Whisper, and Core, with the speaker confirming the transcript. Optional Parakeet
subsequently processed that same recording through its real Swift service and
Core. Neither result proves a complete Android app or full iOS behavioral parity.

## Status vocabulary

- **COMPILING**: builds for Android; execution is not yet demonstrated.
- **FUNCTIONAL**: the stated scenario executed with real implementations.
- **STUBBED**: explicitly limited fallback or missing semantic implementation.
- **UNRESOLVED**: implementation, integration, or evidence is still missing.

FUNCTIONAL applies to the evidence listed, not every input, language, device, or
lifecycle condition. Keep this roadmap current when evidence or scope changes;
link detailed commands and limitations rather than duplicating them here.

## Current capability checkpoint

| Capability | Status | Verified scope / remaining gap |
| --- | --- | --- |
| Core package graph | COMPILING | Android arm64 API 28, static Swift standard library; successful builds are distinct from runtime coverage |
| Whisper native runtime and Swift service | FUNCTIONAL | Real model inference, VAD, and microphone transcript through Core |
| Optional Parakeet native runtime and Swift service | FUNCTIONAL | Real microphone audio through VAD and Core; coexists with Whisper; limitations below |
| WAV decoding and sample conversion | FUNCTIONAL | Mono 16 kHz and stereo 48 kHz speech, silence handling, malformed-input rejection |
| Microphone capture | FUNCTIONAL | Device WAV capture and adb-orchestrated engine handoff; no in-app engine bridge yet |
| Text post-processing | FUNCTIONAL | Real speech output processed by Core; incomplete semantic capabilities limit parity |
| Dictionary and persistence | FUNCTIONAL | Android/macOS persisted canonical output matched across process restart; duplicate rejection, backup recovery diagnostics, and speech-path loading verified; fuzzy correction parity is not established |
| Semantic state publication | FUNCTIONAL | Portable state channel executed on Android; Apple publication retained |
| URL-prefix and file-type handling | FUNCTIONAL | Portable implementations exercised with fixtures; Apple-specific detection retained where applicable |
| Word boundaries | FUNCTIONAL | Unicode tokenization executed on Android and macOS |
| Optional grammatical roles | FUNCTIONAL | Explicitly selected permissively licensed model executed; accuracy and language coverage are limited |
| iOS Whisper Base baseline | FUNCTIONAL | Exact iOS GGML artifact/revision/checksum; existing microphone audio passed through shared service, automatic language metadata, VAD, and dictionary/Core processing |
| Language-specific text groundwork | FUNCTIONAL | Existing Spanish/French list fixtures matched macOS output; speech-accuracy evaluation is outside this experiment |
| Names and lemmas outside Apple | UNRESOLVED | Current portable analyzer explicitly reports them unavailable |
| Semantic date/address protection | STUBBED | Conservative fallback preserves prose; not equivalent to Apple's detection |
| Model installation and management on Android | UNRESOLVED | Runtime trials use explicitly deployed files; full install/download/recovery flow is not demonstrated |
| Background dictation | UNRESOLVED | Required for parity; intentionally deferred to Android host integration |
| Windows/Linux execution | UNRESOLVED | Capability boundaries exist; actual builds and runtime checks remain necessary |

## Next: complete the engine evidence

- [x] Verify dictionary persistence, recovery diagnostics, and the existing
      correction path on Android using host-supplied entries.
- [x] Verify the exact iOS Base model and language metadata routing, and
      reuse language-specific text fixtures. Spanish/French outputs match macOS.
- [ ] Verify supported-language availability and selection through the eventual
      host. Language exposure and routing are required; evaluating recognition
      accuracy across languages is outside this experiment. Do not introduce
      shared English defaults.
- [ ] Audit the semantic NLP behavior consumed by Core and close practical gaps
      with portable implementations or small platform adapters. Reuse the same
      fixtures on Apple and Android; do not recreate an entire Apple framework.
- [ ] Exercise model storage, availability, install failure, and reload paths
      behind their existing owners before claiming device model management.
- [ ] Extend audio/runtime evidence to repeated sessions, cancellation, resource
      release, varied sample formats, and longer utterances where feasible.

Parakeet is optional. Keep it only while integration remains practical; a
Whisper-only release remains viable. The native adapter currently loads lazily,
cannot abort native computation mid-call, and defers model destruction until the
call returns. Word timestamps, confidence, no-speech probabilities, language
detection, and alternatives are not exposed by this adapter. Its tested model
ignores language hints. These limitations must remain visible to host developers.

## Later: Android host integration and iOS dictation parity

- [ ] Connect capture to the engine inside an Android process without adb.
- [ ] Preserve the distinction between an enabled microphone session, an active
      utterance, processing, cancellation, and session shutdown.
- [ ] Continue an active recording when leaving the app or locking the screen.
      Returning to the app must reconnect to existing state rather than start a
      new capture. Audit Android's required background-microphone mechanism at
      implementation time; OS requirements do not prescribe new product controls.
- [ ] Match iOS's interruption and recovery behavior, including microphone loss
      and route changes. Preserve recoverable audio where the existing flow does.
- [ ] Carry over existing idle-session policy and utterance safety behavior from
      their source of truth, without copying thresholds into Android UI code.
- [ ] Connect dictation commands and processed output to the eventual input host,
      preserving cancellation, capitalization, spacing, replacement, and insertion
      semantics through real host tests.
- [ ] Validate model/language selection, dictionary editing and persistence, and
      user-visible failures through the completed dictation flow.
- [ ] Preserve the existing model-download journey, including downloading a
      Whisper model during onboarding, progress, cancellation/retry, installation
      readiness, and actionable failure recovery. Audit the iOS flow and its
      download/state owners before implementing Android presentation. Design and
      onboarding UI work remain later milestones, not part of package portability.
- [ ] Only then complete the surrounding app surfaces and platform integration.

The iOS reference is explicit: background entry in
`TranscriptionManager.handleAppDidEnterBackground()` dismisses return-to-host
presentation; it does not stop recording. `AudioRecorder` keeps monitoring separate
from the current utterance and uses the background audio session. The current
diagnostic APK stops on Home and does not satisfy this requirement. That harness
limitation must not become engine policy.

## Architecture and distribution boundaries

Prefer portable Swift, then semantic capability interfaces, then narrow platform
implementations. Keep capture, inference, linguistic analysis, model storage,
persistence, and state separate from UI. Preserve existing Apple implementations
until replacements have demonstrated equivalent behavior.

The manually maintained pronunciation lexicon and common-word resource remain
their existing source of truth. Dictionary correction stays downstream of speech
recognition. Model misrecognitions are not grounds for hard-coded package fixes.

Record direct and transitive licenses/provenance for code, native libraries,
models, and data before including them in a distributable artifact. MIT-licensed
KeyVox code does not relicense separately licensed assets. The optional Parakeet
trial model is CC BY 4.0 with attribution requirements; its weights are not bundled.

Before beginning Windows implementation, verify the portable package graph there,
then supply native packaging and platform capabilities behind these boundaries.
Parakeet's current symbol isolation is ELF-specific; Windows needs an appropriate
export boundary. No current Android success constitutes Windows/Linux validation.

## Evidence and implementation references

- [Speech engine commands and detailed execution record](../../Tools/KeyVoxSpeechHarness/README.md)
- [Diagnostic microphone host](../../Tools/AndroidCaptureHarness/README.md)
- [Native Parakeet build and provenance](../../Tools/ParakeetNative/README.md)
- [Optional Swift Parakeet backend and limitations](../../Packages/KeyVoxParakeetNative/README.md)
- [Portable linguistic model and accuracy limits](../../Tools/Models/averaged-perceptron-tagger-eng/README.md)
- [Runtime/model licensing record](../../Tools/Licenses/README.md)

Recent milestones: [native Parakeet packaging](https://github.com/macmixing/keyvox-platform-lab/pull/19)
and [Swift/Core integration](https://github.com/macmixing/keyvox-platform-lab/pull/20).
Apple regression checks passed alongside that integration; continue distinguishing
package checks, Apple app checks, and Android device execution in future records.

## Model parity source of truth

Use the existing iOS `DictationModelCatalog` and `ModelArtifacts` values for model
identity, revision, and integrity, and shared `WhisperService` for decoding settings.
The Base artifact is identical on Android; its CPU backend replaces Apple's
Core ML acceleration. Earlier Tiny runs are historical diagnostics only.

The optional native Parakeet Q8 GGUF trial is not equivalent to iOS's cataloged
Core ML EncoderInt4 model. Exact artifact/quantization parity remains UNRESOLVED;
that capability trial does not select a different product model.
