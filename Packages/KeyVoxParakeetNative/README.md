# KeyVoxParakeetNative

Optional native inference implementation of `ParakeetRuntimeBackend`. Core and
the Apple apps do not depend on this package. Hosts opt in through
`ParakeetService(modelURLResolver:backendFactory:)` or `Parakeet`'s existing factory.

```swift
let service = ParakeetService(
    modelURLResolver: { modelURL },
    backendFactory: { try NativeParakeetBackend(modelURL: $0) }
)
```

Build the pinned library with `Tools/ParakeetNative/build-android.sh`, then pass
its include and library directories to Swift using `-Xcc -I<prefix>/include` and
`-Xlinker -L<prefix>/lib`. Deploy `libparakeet.so`, the matching NDK C++ runtime,
and their installed notices. Android is the verified native target; Linux uses
the same C boundary but remains unverified. Apple hosts retain Core ML and can
run the portable lifecycle tests without the optional native library.

The adapter expects mono 16 kHz finite Float samples. Model loading and inference
run on one serial worker. Cancelling invalidates results, and unload schedules
model destruction after active work; neither operation can interrupt native
computation. The model loads on first transcription, so the current service
warmup creates the adapter but does not preload native weights. Invalid models
or an incompatible C ABI fail at that first load.

Results follow the existing whole-utterance segment contract, with duration
derived from the supplied audio. Word timestamps, confidence, no-speech
probabilities, detected language, and alternatives are unavailable in this
adapter. `enableTimestamps` and `maxAlternatives` do not enable those capabilities.
Language hints are forwarded; the tested TDT-v3 model ignores them. A host may
provide its known processing language independently; no requested language is
reported as detected. The existing downstream dictionary remains responsible
for corrections.

This package contains first-party Swift and an include shim, not vendored native
code or models. The pinned native dependencies and permissive licenses are
recorded in `Tools/ParakeetNative/README.md` (MIT, MIT-0, Arm's permissive dual
license, and NDK runtime notices). The separately licensed trial model is CC BY
4.0 and is not bundled. Its provenance and redistribution requirements are
recorded there. Preserve those notices when distributing the native runtime.

The speech harness command is:

```sh
KeyVoxSpeechHarness parakeet-file-pipeline <model.gguf> <audio.wav> [processing-language]
```

It uses the shared file loader, real ParakeetService/VAD, optional native backend,
and Core processing. No screen lifecycle or frontend behavior is introduced.
