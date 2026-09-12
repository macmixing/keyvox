# Android dictation parity roadmap

## Destination and current scope

Bring KeyVox's existing iOS dictation behavior to Android, preserving the shared
engine and leaving clean capability boundaries for Windows and Linux. TTS and
Vibes are outside this phase; retain extension points for later work.

Current work includes the real application and IME in `Android/`, alongside
package portability and real engine execution. The older capture APK under
`Tools/` remains a separate diagnostic host.
The containing app now includes Home, Dictionary, and Style surfaces, while the
IME includes the KeyVox keyboard, dictation controls, and list/paragraph variants.
Onboarding, billing, complete settings/model presentation, and remaining lifecycle
work come later. Native platform presentation remains free to use whichever
technology best supports the app.

The first real Android microphone recording has already passed through VAD,
Whisper, and Core, with the speaker confirming the transcript. Optional Parakeet
subsequently processed that same recording through its real Swift service and
Core. Neither result proves a complete Android app or full iOS behavioral parity.

## Status vocabulary

- **COMPILING**: builds for Android; execution is not yet demonstrated.
- **FUNCTIONAL**: the stated scenario executed with real implementations.
- **STUBBED**: explicitly limited fallback or missing semantic implementation.
- **UNRESOLVED**: implementation, integration, or evidence is still missing.

FUNCTIONAL applies only to the behavior described, not every input, language,
device, or lifecycle condition. Keep this roadmap current when scope changes;
link detailed records and limitations rather than duplicating them here.

## Current capability checkpoint

| Capability | Status | Current behavior / remaining work |
| --- | --- | --- |
| Core package graph | FUNCTIONAL | The portable package graph builds for Android arm64 API 28; Apple-only binary dependencies are conditionally excluded |
| Whisper native runtime and Swift service | FUNCTIONAL | Real model inference, VAD, and microphone transcript through Core |
| Whisper cancel/restart lifecycle | FUNCTIONAL | Cancellation after native encoder entry followed immediately by replacement dictation completed on the same service; canceled output suppressed and replacement published once |
| Optional Parakeet native runtime and Swift service | FUNCTIONAL | Real microphone audio through VAD and Core; coexists with Whisper; limitations below |
| WAV decoding and sample conversion | FUNCTIONAL | Mono 16 kHz and stereo 48 kHz speech, silence handling, malformed-input rejection |
| Microphone capture | FUNCTIONAL | Real Android IME starts capture in another app; installed Swift bridge consumes captured PCM; view visibility does not stop recording |
| Text post-processing | FUNCTIONAL | Real Android NPU speech output runs through shared Core processing with the selected portable capabilities |
| Dictionary and persistence | FUNCTIONAL | The shared dictionary owner supplies canonical persistence, duplicate rejection, backup recovery diagnostics, speech-path loading, and fuzzy correction to Android |
| Semantic state publication | FUNCTIONAL | The portable state channel supplies Android while Apple retains its existing publication path |
| URL-prefix and file-type handling | FUNCTIONAL | Portable implementations supply Android while Apple retains its platform-specific detection where applicable |
| Word boundaries | FUNCTIONAL | Portable Unicode tokenization supplies Android and other non-Apple hosts |
| Portable grammatical roles | FUNCTIONAL | Android injects the focused perceptron and WordNet provider; exact selection and outputs are instrumented; unsupported languages retain explicit unavailable semantics |
| iOS Whisper Base baseline | FUNCTIONAL | Exact iOS GGML artifact/revision/checksum; existing microphone audio passed through shared service, automatic language metadata, VAD, and dictionary/Core processing |
| Language-specific text groundwork | FUNCTIONAL | Shared Spanish/French list formatting is available; speech-recognition accuracy remains outside this experiment |
| Complete spoken-number parsing | FUNCTIONAL | The shared parser rejects partial candidates and handles math equations, compound exponents, and spoken years |
| Names and lemmas outside Apple | FUNCTIONAL | Portable name identity and noun inflection cover the behavior Core consumes. General lemmas remain explicitly unavailable; Apple retains its native lemma capability |
| Semantic date/address protection | FUNCTIONAL | Apple retains native detection; Android uses portable numeric protection with shared year, date, address, quantity, Unicode, and missing-language expectations |
| Foreground model download transport | FUNCTIONAL | Swift downloaded exact Base on the phone; KeyVoxModels verified SHA-256 before publication; independent device checksum matched and verified weights ran through real inference/Core |
| Shared model file integrity | FUNCTIONAL | KeyVoxModels owns streaming SHA-256, progress, and error behavior; existing iOS file hashing delegates to it, while installation readiness remains a separate concern |
| Whisper model failure and reload | FUNCTIONAL | Absent selection and invalid files remain explicit failures; unload and reload preserve the exact Base model boundary |
| Model installation and management on Android | FUNCTIONAL | Containing app downloads exact Base and verifies it before readiness; resumability, onboarding journey, cancellation and recovery remain unresolved |
| Background dictation | FUNCTIONAL | Physical-device capture continues after Home and keyboard cancellation releases it; lock-screen, interruptions, process death and warm-session parity remain unresolved |
| Cursor-aware dictation composition | FUNCTIONAL | Composition handles empty fields, text on both cursor sides, punctuation replacement, selected-text replacement, non-BMP Unicode, unavailable/capped surrounding text, no speech, and stale editor generations. Editors may withhold context, where insertion deliberately preserves the processed transcript rather than guessing boundary changes |
| Containing app navigation and presentation | FUNCTIONAL | Home, Dictionary, and Style tabs use the Android-owned KeyVox presentation foundation; onboarding, billing, and remaining settings surfaces are not complete |
| Home dashboard | FUNCTIONAL | Device-local weekly words, latest transcription, and Android-targeted promotions are connected to their existing state owners |
| Dictionary app experience | FUNCTIONAL | List, sort, add, edit, delete, duplicate rejection, persistence, recovery, and casing-cache refresh flow through the shared dictionary owner |
| Style settings | FUNCTIONAL | Paragraph and list preferences persist in the containing app and are supplied to shared processing; broader style-rewrite product work remains outside this phase |
| Keyboard presentation and editing | FUNCTIONAL / UNRESOLVED | The installed IME includes the KeyVox key grid, symbol layout, toolbar, previews, haptics, dictation state, and safe editor replacement. Broader editor/device compatibility and remaining lifecycle recovery are unresolved |
| Paragraph and list controls | FUNCTIONAL | Toolbar controls expose deterministic processed variants and reject replacement after text, selection, cursor, or editor-generation changes |
| Android launcher and in-app artwork | FUNCTIONAL | Adaptive/round launcher resources and Android-native KeyVox artwork are present; root licensing protection for first-party Android brand assets is part of the current integration pass |
| Dictation performance | FUNCTIONAL / UNRESOLVED | Optional Qualcomm NPU encoder now executes in the installed shell with the existing Base decoder, VAD, and Core: 388–438 ms provider versus 2.394–2.489 s CPU with identical processed-output hashes. CPU fallback is available. Only the SM8850 artifact is currently supported; broader device, thermal, and reliability work remains unresolved. SDK distribution terms and Eigen source-access requirements are recorded with the retained notices. See [measurements](PERFORMANCE.md) |
| Windows/Linux execution | UNRESOLVED | Capability boundaries exist; actual builds and runtime checks remain necessary |

## Next: complete engine reliability

- [x] Verify dictionary persistence, recovery diagnostics, and the existing
      correction path on Android using host-supplied entries.
- [x] Verify the exact iOS Base model and language metadata routing, and
      reuse language-specific text fixtures. Spanish/French outputs match macOS.
- [x] Exercise the existing shared language catalog and service selection on
      Android: automatic, explicit supported selection, and unsupported-language
      fallback. Isolated instrumentation used the saved recording; no recognition
      accuracy claim is made for other languages.
- [ ] Verify supported-language availability and selection through the eventual
      host. Language exposure and routing are required; evaluating recognition
      accuracy across languages is outside this experiment. Do not introduce
      shared English defaults.
- [x] Audit the semantic NLP behavior consumed by Core and close practical gaps
      with portable implementations behind existing capability boundaries. The
      resulting implementation and its historical comparison are recorded in the
      [bakeoff record](CORE_LINGUISTIC_BAKEOFF.md).
- [x] Exercise model storage, availability, install failure, and reload paths
      behind their existing owners. Exact Base download, verification, unload,
      failure, and reload have executed; onboarding and resumability remain open.
- [x] Extend audio/runtime evidence to repeated sessions, cancellation, resource
      release, varied sample formats, and longer utterances. Lock-screen,
      interruption, process-death, and broader reliability work remain open.

Whisper lifecycle supports immediate cancel/restart with the exact Base model on
Android. Per-context serialization and owned request strings prevent concurrent
use of one native GGML context. Native work already underway still finishes before
its replacement can run; immediate native abort remains unavailable. The shared
chunker handles longer audio and silence boundaries without bundling diagnostic
audio in the repository or distribution.

Parakeet is optional. Keep it only while integration remains practical; a
Whisper-only release remains viable. The native adapter currently loads lazily,
cannot abort native computation mid-call, and defers model destruction until the
call returns. Word timestamps, confidence, no-speech probabilities, language
detection, and alternatives are not exposed by this adapter. Its current model
ignores language hints. These limitations must remain visible to host developers.

## Android host integration and remaining iOS dictation parity

- [x] Connect capture to the engine inside an Android process without adb.
- [x] Preserve the distinction between an enabled microphone session, an active
      utterance, processing, cancellation, and session shutdown through the
      process-owned dictation session and capture service.
- [x] Continue an active recording when leaving the app and reconnect to the
      existing session state on return.
- [ ] Verify lock-screen recording, interruption, and recovery behavior. Android's
      required foreground microphone service is already isolated from product
      controls; remaining work is lifecycle parity and recovery evidence.
- [ ] Match iOS's interruption and recovery behavior, including microphone loss
      and route changes. Preserve recoverable audio where the existing flow does.
- [ ] Carry over existing idle-session policy and utterance safety behavior from
      their source of truth, without copying thresholds into Android UI code.
- [x] Connect dictation commands and processed output to the Android IME through
      `KeyVoxTextComposition`, preserving cancellation/no-speech delivery,
      capitalization, spacing, punctuation, selection replacement, Unicode, and
      stale-editor rejection in installed device checks. Human testing across real
      third-party editors remains required because Android editors can deny or cap
      surrounding text; unavailable context uses an explicit conservative fallback.
- [x] Validate dictionary editing and persistence through the shared owner and
      connect the resulting state to dictation processing.
- [ ] Complete model/language selection presentation and actionable user-visible
      failure handling through the final dictation flow.
- [ ] Preserve the existing model-download journey, including downloading a
      Whisper model during onboarding, progress, cancellation/retry, installation
      readiness, and actionable failure recovery. Audit the iOS flow and its
      download/state owners before implementing Android presentation. Design and
      onboarding UI work remain later milestones, not part of package portability.
- [ ] Complete onboarding, remaining settings/model surfaces, billing, and the
      outstanding lifecycle/platform integration.

The iOS reference is explicit: background entry in
`TranscriptionManager.handleAppDidEnterBackground()` dismisses return-to-host
presentation; it does not stop recording. `AudioRecorder` keeps monitoring separate
from the current utterance and uses the background audio session. The older
diagnostic APK stops on Home. The real `Android/` host now keeps capture alive
after Home; interruption and warm-session parity remain open.

## Architecture and distribution boundaries

Prefer portable Swift, then semantic capability interfaces, then narrow platform
implementations. Keep capture, inference, linguistic analysis, model storage,
persistence, and state separate from UI. Preserve existing Apple implementations
until replacements have demonstrated equivalent behavior.

`KeyVoxModels` owns shared model metadata and is the boundary for new model
storage, download, and integrity work. Apps and diagnostic hosts depend on it
directly. Core's existing Whisper and Parakeet services remain in Core; model
management must not be added there or made a Core dependency.

The manually maintained pronunciation lexicon and common-word resource remain
their existing source of truth. Dictionary correction stays downstream of speech
recognition. Model misrecognitions are not grounds for hard-coded package fixes.

Direct and transitive licenses/provenance for current code, native libraries,
models, and data are retained with their distributable artifacts. Keep that record
synchronized with the root third-party notice index during this integration pass.
MIT-licensed KeyVox code does not relicense separately licensed assets, and the
root license exclusions must cover Android's first-party app icon and custom brand
artwork alongside the existing Apple exclusions. The optional Parakeet trial model
is CC BY 4.0 with attribution requirements; its weights are not bundled.

Before beginning Windows implementation, verify the portable package graph there,
then supply native packaging and platform capabilities behind these boundaries.
Parakeet's current symbol isolation is ELF-specific; Windows needs an appropriate
export boundary. No current Android success constitutes Windows/Linux validation.

## Evidence and implementation references

- [Real Android application, IME, build and capability boundaries](../README.md)

- [Speech engine commands and detailed execution record](../../Tools/KeyVoxSpeechHarness/README.md)
- [Diagnostic microphone host](../../Tools/AndroidCaptureHarness/README.md)
- [Native Parakeet build and provenance](../../Tools/ParakeetNative/README.md)
- [Optional Swift Parakeet backend and limitations](../../Packages/KeyVoxParakeetNative/README.md)
- [Portable linguistic model and accuracy limits](../../Tools/Models/averaged-perceptron-tagger-eng/README.md)
- [Core linguistic bakeoff, failure ledger, performance, and licensing](CORE_LINGUISTIC_BAKEOFF.md)
- [WordNet lexical indexes and distribution terms](../../Tools/Models/wordnet-3.0/README.md)
- [Runtime/model licensing record](../../Tools/Licenses/README.md)

Recent product-surface milestones include the [Home tab](https://github.com/macmixing/keyvox-platform-lab/pull/45),
[Dictionary experience](https://github.com/macmixing/keyvox-platform-lab/pull/46),
[Style tab](https://github.com/macmixing/keyvox-platform-lab/pull/50), and
[paragraph/list controls](https://github.com/macmixing/keyvox-platform-lab/pull/52).

## Model parity source of truth

The existing iOS Base identity, revision, and integrity values are shared through
`KeyVoxModels.WhisperBaseModelArtifact`; Apple catalogs consume that definition. The
harness exposes it with `whisper-model` for Android host verification. Use shared
`WhisperService` for decoding settings.
The Base artifact is identical on Android; its CPU backend replaces Apple's
Core ML acceleration. Earlier Tiny runs are historical diagnostics only.

The optional native Parakeet Q8 GGUF trial is not equivalent to iOS's cataloged
Core ML EncoderInt4 model. Exact artifact/quantization parity remains UNRESOLVED;
that capability trial does not select a different product model.
