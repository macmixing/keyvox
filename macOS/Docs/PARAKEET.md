# Parakeet Integration Plan for KeyVox

## Purpose

This document is the implementation plan for adding Parakeet-based local ASR to KeyVox while preserving the current Whisper user experience.

The plan is intentionally phased.

- macOS comes first
- Whisper remains the default provider until parity is proven
- Parakeet UI polish comes after on-device bring-up and parity validation
- iOS starts only after the provider contract is stable on macOS
- the target model for both platforms is `Parakeet TDT v3 (0.6b)`

The goal is not just to make Parakeet transcribe.

The goal is to make Parakeet feel like a backend swap inside KeyVox rather than a new product behavior path.

## Product Decision Summary

These decisions are locked into this plan.

1. Scope the first implementation to macOS only.
2. Keep Whisper as the default provider during development and initial rollout.
3. Use `Parakeet TDT v3 (0.6b)` as the Parakeet target model.
4. Use the exact same Parakeet model on macOS and iOS.
5. Keep language behavior on automatic detection for v1.
6. Focus on feature parity between Whisper and Parakeet before adding a polished provider selector.
7. Do not change downstream formatting, paste, warning, or overlay behavior unless parity work requires it.
8. Treat Intel macOS support as a real compatibility target, not an afterthought.
9. Do not ship intentional feature gaps in the name of an experimental rollout.
10. Move to iOS only after macOS provider architecture and parity behavior are proven stable.

## Success Criteria

Parakeet is successful only when all of the following are true:

- the app can load `Parakeet TDT v3 (0.6b)` locally on macOS
- a full hold-to-record and release-to-transcribe session completes on device
- paste behavior remains unchanged
- no-speech and warning behavior remain consistent with Whisper
- post-processing quality remains consistent with Whisper
- switching between providers does not require architectural forks throughout the app
- Apple Silicon and Intel Macs both remain part of the supported macOS compatibility story
- iOS later adopts the same model and provider contract without rethinking the shared pipeline

## Guiding Principles

1. Preserve KeyVox ownership of dictation behavior.
KeyVox should continue to own chunking, no-speech semantics, post-processing, paste, warnings, and UX state transitions.

2. Keep model runtime details behind a package boundary.
`KeyVoxParakeet` should isolate runtime churn from app code.

3. Separate architecture work from product polish.
Provider seams and parity should land before selector UX and wording changes.

4. Prefer shared abstractions over parallel product logic.
If macOS and iOS need the same provider behavior, that logic should live in shared contracts or packages rather than duplicated platform-specific flows.

5. Keep the Whisper path healthy at all times.
Whisper remains the fallback until Parakeet has proven parity.

6. Do not redefine parity downward.
If parity requires provider-side or app-side compatibility work, do that work instead of downgrading the plan.

7. Preserve the existing compatibility philosophy.
Whisper already carries compute-path compatibility logic. Parakeet should be planned with the same mindset instead of assuming only the fastest path matters.

## Current Architecture Snapshot

Today, the codebase is already close to the shape we want:

- `DictationPipeline` already depends on `DictationTranscriptionProviding`
- downstream post-processing and paste behavior are already provider-agnostic in spirit
- most concrete Whisper coupling is concentrated in app wiring and model management

Current coupling that must be removed first:

- app-layer managers still directly own or call `WhisperService`
- app service registries construct Whisper concretely
- model management is Whisper-specific in storage layout, artifact set, and naming
- user-facing model copy is Whisper-oriented

That makes this a medium-sized refactor with a clear center of gravity rather than a full architectural rewrite.

## User-Visible Behavior That Must Stay Stable

These behaviors are the parity baseline.

1. Recording flow parity
- hold key to record
- release to transcribe
- hands-free lock behavior stays the same
- cancel behavior stays the same

2. Overlay and state parity
- same state machine
- same sound timing
- same overlay transitions

3. No-speech parity
- same empty capture handling
- same muted mic and no-speech warnings
- same suppression of low-value or hallucinated output

4. Output parity
- same dictionary correction path
- same list formatting behavior
- same normalization behavior
- same all-caps override behavior

5. Paste parity
- same Accessibility-first insertion
- same fallback path
- same clipboard restore behavior

6. Model readiness parity
- same clear model-installed versus model-missing gating
- same predictable warmup and unload lifecycle

7. Language behavior parity
- automatic language behavior only for v1
- no platform-specific model or language-mode drift between macOS and iOS

## Recommended Technical Shape

### 1. Add a package-first Parakeet wrapper

Create `KeyVoxParakeet` as a sibling to `KeyVoxWhisper`.

The package should:

- expose a stable Swift API owned by this project
- hide runtime backend details
- accept resolved model paths from app code rather than owning app storage decisions
- support cancellation, health checks, and deterministic error mapping
- target `Parakeet TDT v3 (0.6b)` as the initial model contract for both macOS and iOS
- support artifact integrity validation requirements expected by the host app

### 2. Expand the provider contract

The current transcription protocol is the right base, but the app also needs lifecycle and readiness abstractions.

Recommended shape:

```swift
protocol DictationTranscriptionProviding: AnyObject {
    var lastResultWasLikelyNoSpeech: Bool { get }
    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    )
}

protocol DictationTranscriptionLifecycleProviding: AnyObject {
    func warmup()
    func cancelTranscription()
    func unloadModel()
    func updateDictionaryHintPrompt(_ prompt: String)
}

protocol DictationModelReadinessProviding: AnyObject {
    var isModelReady: Bool { get }
}

typealias DictationProvider =
    DictationTranscriptionProviding &
    DictationTranscriptionLifecycleProviding &
    DictationModelReadinessProviding
```

### 3. Keep downstream behavior app-owned

Do not push these responsibilities into the Parakeet runtime package:

- chunking policy
- suspicious-short retry policy
- no-speech fallback semantics
- dictionary prompt gating
- post-processing
- paste behavior

That keeps Whisper and Parakeet aligned from the same product rules.

### 4. Hide runtime choice behind `KeyVoxParakeet`

Inside `KeyVoxParakeet`, use an internal backend abstraction so implementation can change later.

The package should allow:

- a preferred CoreML path
- reduced-compute compatibility behavior when required
- machine-specific validation without leaking backend complexity into app code

The app should not care which backend is active.

## Phased Rollout

### Phase 0: Freeze Scope and Baseline

Purpose:
Lock the initial effort to the right problem before any code changes.

In scope:

- macOS only
- Whisper default
- architecture and parity work
- public development of the feature
- `Parakeet TDT v3 (0.6b)` as the committed model target
- automatic language behavior for v1
- Intel compatibility as part of macOS scope

Out of scope:

- polished provider selector
- onboarding polish for multiple providers
- iOS implementation
- making Parakeet the default
- explicit language selection UI

Tasks:

- document the current Whisper parity baseline
- capture current no-speech thresholds and hint-gating behavior
- identify the minimum set of app seams that must become provider-agnostic
- define explicit parity validation on both Apple Silicon and Intel Macs

Exit criteria:

- team agrees the first milestone is "Parakeet works locally on macOS with Whisper-like behavior"
- team agrees the initial Parakeet target is `TDT v3 (0.6b)` with automatic language handling
- no product work begins for iOS yet

### Phase 1: Shared Provider Seams, No Behavior Change

Purpose:
Make the current Whisper path go through provider abstractions without changing user-visible behavior.

Why first:
This is the highest leverage phase. Once complete, every later phase gets easier on both macOS and iOS.

Tasks:

- add lifecycle and readiness protocols next to the current transcription contract
- remove direct app-layer dependence on `WhisperService` where provider interfaces should be used instead
- introduce a provider factory or provider registry in app wiring
- make app service construction route through provider-aware seams
- keep `DictationPipeline` provider-agnostic and avoid provider-specific extensions embedded in the pipeline file
- keep current Whisper behavior bit-for-bit

Acceptance criteria:

- the app still uses Whisper by default
- no UI changes
- no behavior changes in recording, warnings, paste, or formatting
- provider-specific logic is centralized rather than spread through managers

Decision gate:

- if this phase still leaves Whisper branching in multiple app managers, do not start Parakeet integration yet

### Phase 2: Create `KeyVoxParakeet` Package Skeleton

Purpose:
Create the package boundary before runtime work begins.

Tasks:

- add `Packages/KeyVoxParakeet`
- define public result, segment, params, runtime, and error surfaces
- add cancellation-aware API design
- add internal runtime backend abstraction
- add package tests for init failure mapping, invalid frames, cancellation surface behavior, and backend-to-public mapping
- encode the initial package assumptions around `Parakeet TDT v3 (0.6b)` without baking platform-specific UI policy into the package

Acceptance criteria:

- the package builds independently
- the public API is app-usable even if the runtime implementation is still skeletal
- app code does not reach into backend internals

Decision gate:

- confirm the package API is stable enough that app integration can proceed without reworking the surface every phase

### Phase 3: macOS Hidden Bring-Up

Purpose:
Get Parakeet loaded and transcribing locally on macOS before any polish work.

This is the first phase where Parakeet must actually run on device.

Tasks:

- implement the first working runtime backend inside `KeyVoxParakeet`
- add a Parakeet provider implementation in `KeyVoxCore` that conforms to the shared provider contracts
- map runtime output into `TranscriptionProviderResult`
- support warmup, unload, cancellation, and deterministic failure behavior
- add enough provider selection plumbing to exercise Parakeet during development without shipping a polished selector yet
- validate the same model artifact family intended for iOS later rather than using a temporary macOS-only model

Important constraints:

- Whisper remains the default provider
- no onboarding rewrite yet
- no final settings UX yet
- no iOS work yet

Acceptance criteria:

- Parakeet can load `TDT v3 (0.6b)` on macOS
- a full record-to-transcribe flow completes without crashing
- switching between Whisper and Parakeet is possible in development
- downstream post-processing and paste still use the same pipeline

Decision gate:

- proceed only if local bring-up is real and stable
- if runtime packaging becomes the blocker, solve that inside `KeyVoxParakeet` before expanding app work

### Phase 4: macOS Parity Hardening

Purpose:
Make Parakeet behave like Whisper from the user’s point of view.

This is the most important product phase.

Tasks:

- preserve app-level chunking for v1 parity
- preserve dictionary-hint gating behavior
- preserve automatic language behavior for v1
- implement no-speech semantics using runtime signals where available
- add deterministic fallback heuristics where runtime signals are missing
- compare short utterances, medium utterances, silence, noise, and muted mic behavior against Whisper on both Apple Silicon and Intel
- ensure cancellation remains immediate
- ensure repeat dictations do not wedge the runtime

Acceptance criteria:

- no-speech behavior is acceptably close to Whisper
- perceived feel on Intel is acceptably close to Whisper
- suspicious-short and empty-result handling are stable
- paste reliability is unchanged
- overlay and state flow remain unchanged
- Whisper still works unchanged

Decision gate:

- do not start product polish until Parakeet is credible as a real macOS option across Apple Silicon and Intel

### Phase 5: Provider-Aware Model Management

Purpose:
Generalize model lifecycle management only after Parakeet transcription is real.

Why here:
There is no value in polishing install flows for a provider that is not yet working end-to-end.

Tasks:

- generalize model install, remove, readiness, and integrity checks to be provider-aware
- give each provider a clean storage layout
- keep provider artifact knowledge isolated in provider-specific model descriptors or managers
- keep user-facing readiness state consistent regardless of provider
- preserve Whisper install behavior while adding Parakeet support
- keep the model definition aligned across macOS and iOS so both platforms are built around the same Parakeet artifact family
- pin the expected SHA-256 values for every downloaded Parakeet artifact
- verify downloaded Parakeet artifacts against the expected SHA-256 values before extraction or activation
- write an install manifest for Parakeet artifacts after successful verification
- make readiness validation fail closed when the manifest is missing, unreadable, version-mismatched, or hash-mismatched

Acceptance criteria:

- active provider readiness reflects the selected provider only
- install and remove flows work for both providers
- provider lifecycle hooks and on-disk state stay aligned
- Parakeet model activation requires verified artifacts and a valid install manifest

Decision gate:

- if model management still assumes Whisper naming or artifact structure in core flow, do not move to selector UI yet

### Phase 6: macOS Productization and Selector UI

Purpose:
Add the polished user-facing provider experience only after architecture and parity are in place.

Tasks:

- add a provider selector in settings
- make onboarding model setup provider-aware
- update warning copy to avoid Whisper-only phrasing
- make status gating reflect the active provider
- keep Whisper as default until parity is proven over time
- keep automatic language behavior as the only supported language mode for this first Parakeet rollout

Acceptance criteria:

- users can understand which provider is active
- users can install and remove the active provider model cleanly
- onboarding stays deterministic and easy to follow
- switching providers does not require restart or manual cleanup

Decision gate:

- only consider changing the default away from Whisper after this phase and after real parity evidence exists

### Phase 7: Extract Cross-Platform Lessons Before iOS

Purpose:
Do not rush into iOS with macOS-specific assumptions still embedded in the provider design.

Tasks:

- review which provider abstractions are truly shared
- extract any macOS-only assumptions from provider APIs
- confirm what is reusable from `KeyVoxParakeet`, `KeyVoxCore`, and shared model management logic
- document what remains platform-specific in app wiring, recorder behavior, lifecycle, and UX
- confirm the exact same `TDT v3 (0.6b)` model contract carries over to iOS unchanged

Acceptance criteria:

- iOS work has a clear adoption path
- the iOS effort is adapting a proven provider contract rather than inventing a second one

### Phase 8: iOS Provider Wiring and Hidden Bring-Up

Purpose:
Adopt the proven provider contract on iOS without starting with polish.

Tasks:

- route iOS transcription wiring through the same provider abstractions
- add iOS integration for the shared `KeyVoxCore` Parakeet provider using the already-proven package boundary
- keep Whisper default
- add minimal internal switching needed for development and validation
- preserve iOS-specific session and recorder behavior
- use the exact same Parakeet model family chosen for macOS, not a platform-specific substitute

Acceptance criteria:

- iOS can load and use `TDT v3 (0.6b)` locally
- shared provider behavior stays aligned with macOS
- iOS-specific recording/session flows are not regressed by provider abstraction work

Decision gate:

- do not start iOS selector polish until hidden bring-up is stable

### Phase 9: iOS Parity and Productization

Purpose:
Finish the iOS side using the same order that worked on macOS.

Tasks:

- validate parity for no-speech handling, cancellation, formatting, and model readiness
- generalize any remaining model management differences needed for iOS
- add provider-aware UI where appropriate
- keep Whisper as default until parity confidence is high
- keep automatic language behavior aligned with macOS for the first release

Acceptance criteria:

- iOS user-visible behavior remains consistent with current Whisper expectations
- provider-specific wiring is localized rather than spread through the app

## Execution Order Summary

This is the recommended order, with no phase skipping:

1. provider seams with no behavior change
2. `KeyVoxParakeet` package skeleton
3. macOS hidden Parakeet bring-up
4. macOS parity hardening across Apple Silicon and Intel
5. provider-aware model management
6. macOS selector and onboarding polish
7. cross-platform cleanup
8. iOS hidden Parakeet bring-up with the same model
9. iOS parity and polish

This order matters.

If selector UI comes too early, product polish will outrun provider reality.

If iOS starts too early, the team will duplicate uncertainty across two platforms.

## Detailed Workstreams

### Workstream A: Shared Contracts

Own first:

- provider protocol expansion
- provider factory or registry
- provider-safe pipeline ownership
- removal of direct Whisper assumptions from shared transcription seams

Done when:

- adding a second provider does not require rewriting app managers

### Workstream B: `KeyVoxParakeet`

Own second:

- stable package API
- backend abstraction
- runtime health checks
- cancellation
- error mapping
- `TDT v3 (0.6b)` model integration

Done when:

- app code interacts with Parakeet through one stable package surface only
- the same package surface can support the same model on macOS and iOS

### Workstream C: macOS Provider Integration

Own third:

- Parakeet provider implementation in `KeyVoxCore`
- warmup and unload semantics
- parity behavior mapping
- development-facing provider bring-up
- Apple Silicon and Intel compatibility validation

Done when:

- macOS can run Parakeet end-to-end without product polish
- Intel is part of the validated macOS rollout, not deferred by plan

### Workstream D: Model Management

Own after parity bring-up:

- provider-aware install and remove flows
- integrity checks
- checksum pinning and verification
- install manifest writes and validation
- readiness state
- storage layout

Done when:

- model lifecycle is symmetrical enough for both providers

### Workstream E: Product UX

Own last on each platform:

- selector UI
- onboarding wording
- warning copy
- active-provider readiness presentation

Done when:

- the user can understand and control the provider without learning internal implementation details

## Behavior Baseline to Preserve

These constants and policies are the initial parity target:

- recorder contract stays mono Float32 at 16kHz
- model target stays `Parakeet TDT v3 (0.6b)` on both macOS and iOS
- dictionary hint gating stays based on capture quality and minimum duration
- no-speech behavior stays conservative
- suspicious short decode handling stays app-owned
- empty decode retry policy stays app-owned
- one active inference at a time
- explicit cancel remains immediate
- language handling stays automatic for v1
- model downloads are pinned and verified with SHA-256 before use

If Parakeet cannot expose the same confidence or no-speech signals as Whisper, KeyVox should emulate user-visible behavior with deterministic fallback heuristics.

## Testing Strategy

The testing strategy should follow the same rollout order.

### Shared and Package Testing

- keep shared dictation pipeline smoke coverage green
- add provider-agnostic smoke coverage where possible
- add `KeyVoxParakeet` package tests for API behavior and cancellation
- add tests around provider selection default migration behavior
- add tests around Parakeet artifact checksum mismatch and manifest validation failure paths

### macOS Validation

- validate Whisper baseline before changing provider seams
- validate Parakeet bring-up before selector work
- compare latency and no-speech behavior against Whisper on Apple Silicon and Intel
- manually verify paste reliability and warnings
- treat Intel results as part of the main macOS acceptance gate
- verify Parakeet downloads fail closed on checksum mismatch or incomplete install state

### iOS Validation

- validate shared-provider adoption carefully after macOS is stable
- verify iOS session behavior, interruptions, and dictation flow after provider changes
- keep validation focused on parity rather than early UI work
- verify the same model artifact family and automatic language behavior used on macOS
- verify the same checksum-pinning and manifest rules used on macOS

## Rollout Strategy

1. Build provider abstractions first.
2. Bring up Parakeet on macOS behind non-polished controls.
3. Harden parity on macOS across Apple Silicon and Intel.
4. Generalize model management.
5. Add macOS provider UX.
6. Repeat the same order on iOS with the same model.
7. Keep Whisper default until both platform-specific parity checklists are green.

## Risks and Mitigations

1. Runtime packaging risk
- mitigate by isolating backend choice inside `KeyVoxParakeet`

2. No-speech mismatch risk
- mitigate by preserving app-owned fallback heuristics

3. Product polish outrunning backend reality
- mitigate by postponing selector and onboarding work until after parity bring-up

4. Cross-platform duplication risk
- mitigate by finishing the provider contract on macOS first

5. Model lifecycle fragmentation risk
- mitigate by centralizing provider-aware model descriptors and readiness checks

6. Intel compatibility drift risk
- mitigate by making Intel a first-class macOS acceptance gate instead of a later follow-up

7. Artifact integrity drift risk
- mitigate by pinning Parakeet artifact SHA-256 values, writing an install manifest, and failing closed on mismatch or incomplete installs

## Implementation Checklist

- [ ] Freeze the first milestone to macOS parity with Whisper still default
- [ ] Lock the initial model target to `Parakeet TDT v3 (0.6b)`
- [ ] Extract provider lifecycle and readiness abstractions
- [ ] Refactor app wiring so Whisper is not hard-coded through managers
- [ ] Add `KeyVoxParakeet` with a stable public Swift API
- [ ] Add backend abstraction inside `KeyVoxParakeet`
- [ ] Implement the first working Parakeet runtime backend
- [ ] Add the shared Parakeet provider implementation in `KeyVoxCore`
- [ ] Confirm local macOS model load and end-to-end transcription
- [ ] Confirm Apple Silicon and Intel macOS compatibility against Whisper feel
- [ ] Preserve app-owned chunking, no-speech, and retry behavior for parity
- [ ] Harden macOS parity before polishing UI
- [ ] Generalize provider-aware model management
- [ ] Add Parakeet checksum pinning and install manifest validation
- [ ] Add macOS provider selector and onboarding updates
- [ ] Review shared abstractions for cross-platform reuse
- [ ] Adapt iOS to the proven provider contract
- [ ] Bring up the same Parakeet model on iOS behind non-polished controls
- [ ] Harden iOS parity
- [ ] Add iOS provider product polish
- [ ] Keep Whisper fallback intact until parity is proven on both platforms

## Bottom Line

This work should be treated as a staged provider migration, not a model drop-in.

The right order is:

- shared seams
- macOS bring-up
- macOS parity across Apple Silicon and Intel
- macOS polish
- iOS adoption with the same model
- iOS parity
- iOS polish

That order keeps risk low, keeps momentum high, and gives the team one proven integration path before it multiplies work across platforms.
