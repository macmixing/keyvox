import AVFoundation
import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

/// One dictation at a time for the keyboard: collects the audio it sends, then runs the shared
/// dictation pipeline and publishes the transcript the way the containing app does.
@MainActor
final class TranscriptionAUSession {
    enum Outcome {
        case pending
        case transcript(String)
        case noSpeech
        case failed
    }

    private(set) var outcome: Outcome = .pending

    private let services: TranscriptionAUServiceRegistry
    private let captureAccumulator = AudioCaptureAccumulator()
    private var activeUtteranceID = UUID()

    private var dictationPipeline: DictationPipeline?

    init(services: TranscriptionAUServiceRegistry) {
        self.services = services
    }

    /// Starts a dictation. Returns whether the selected dictation model is installed and loading.
    func begin(styleIdentifier: String?) -> Bool {
        abandonCurrentUtterance()
        KeyVoxIPCBridge.removeTranscription()
        selectVibe(styleIdentifier)
        services.applySavedDictationSettings()
        guard services.activeProviderRouter.isModelReady else { return false }

        services.styleRewritePipelineCoordinator.prewarmForUpcomingDictationIfNeeded()
        return true
    }

    /// Adds microphone audio in its capture format and returns the live meter for it.
    func append(audio: Data, sampleRate: Double) -> CaptureMeterUpdate? {
        let frameCount = audio.count / MemoryLayout<Float>.size
        guard frameCount > 0,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: sampleRate,
                  channels: 1,
                  interleaved: false
              ),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        audio.withUnsafeBytes { bytes in
            guard let samples = bytes.bindMemory(to: Float.self).baseAddress else { return }
            channel.update(from: samples, count: frameCount)
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        return captureAccumulator.process(
            inputBuffer: buffer,
            outputFormat: AudioCaptureTuning.outputFormat,
            deadSignalPeakThreshold: AudioCaptureTuning.deadSignalPeakThreshold,
            activeSignalRMSThreshold: AudioCaptureTuning.activeSignalRMSThreshold,
            visualActiveSignalThresholdMultiplier: AudioCaptureTuning.visualActiveSignalThresholdMultiplier,
            deadStateHoldDuration: AudioCaptureTuning.deadStateHoldDuration,
            visualActiveStateHoldDuration: AudioCaptureTuning.visualActiveStateHoldDuration
        )
    }

    /// Ends the capture and transcribes it with the Vibe the keyboard has selected now;
    /// `outcome` changes from pending when it is done.
    func finish(styleIdentifier: String?) {
        selectVibe(styleIdentifier)
        let utteranceID = activeUtteranceID
        let stream = captureAccumulator.snapshot()
        let stoppedCapture = StoppedCaptureProcessor.process(
            snapshot: stream.samples,
            captureDuration: TimeInterval(stream.samples.count) / AudioCaptureTuning.outputFormat.sampleRate,
            maxActiveSignalRunDuration: stream.maxActiveSignalRunDuration,
            gapRemovalRMSThreshold: AudioCaptureTuning.gapRemovalRMSThreshold,
            lowConfidenceRMSCutoff: AudioSilenceGatePolicy.lowConfidenceRMSCutoff,
            trueSilenceWindowRMSThreshold: AudioSilenceGatePolicy.trueSilenceWindowRMSThreshold,
            normalizationTargetPeak: AudioCaptureTuning.normalizationTargetPeak,
            normalizationMaxGain: AudioCaptureTuning.normalizationMaxGain
        )
        captureAccumulator.reset()

        Task {
            let outcome = await transcribe(stoppedCapture, utteranceID: utteranceID)
            guard utteranceID == activeUtteranceID else { return }
            self.outcome = outcome
        }
    }

    /// Abandons the dictation without publishing anything.
    func cancel() {
        abandonCurrentUtterance()
        Task {
            await services.styleRewritePipelineCoordinator.releasePrewarmSession(reason: "utterance-cancelled")
        }
    }

    /// Abandons the dictation and frees the models, for when the keyboard goes away.
    func releaseModels() {
        cancel()
        services.unloadDictationModels()
    }

    private func abandonCurrentUtterance() {
        activeUtteranceID = UUID()
        outcome = .pending
        services.activeProviderRouter.cancelTranscription()
        captureAccumulator.reset()
    }

    /// The shared dictation pipeline, built once the post-processor has loaded.
    private func resolvedDictationPipeline() async -> DictationPipeline {
        if let dictationPipeline { return dictationPipeline }
        let postProcessor = await services.postProcessor
        if let dictationPipeline { return dictationPipeline }

        let pipeline = DictationPipeline(
            transcriptionProvider: services.activeProviderRouter,
            postProcessor: postProcessor,
            dictionaryEntriesProvider: { [services] in
                services.dictionaryStore.entries
            },
            autoParagraphsEnabledProvider: { [services] in
                AppSettingsStore.resolvedAutoParagraphsEnabled(from: services.settingsDefaults)
            },
            listFormattingEnabledProvider: { [services] in
                AppSettingsStore.resolvedListFormattingEnabled(from: services.settingsDefaults)
            },
            capsLockEnabledProvider: { [services] in
                services.settingsDefaults.object(forKey: UserDefaultsKeys.capsLockEnabled) as? Bool ?? false
            },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { [services] text in
                services.recordSpokenWords(from: text)
            },
            pasteText: { _ in },
            processOutputTextWithContext: { [services] context in
                await services.styleRewritePipelineCoordinator.processOutputText(context)
            },
            outputProcessingRequiresDeterministicVariantsProvider: { [services] in
                services.styleRewritePipelineCoordinator.requiresDeterministicVariantsForOutputProcessing
            }
        )
        dictationPipeline = pipeline
        return pipeline
    }

    private func transcribe(_ stoppedCapture: StoppedCapture, utteranceID: UUID) async -> Outcome {
        let coordinator = services.styleRewritePipelineCoordinator
        guard !stoppedCapture.outputFrames.isEmpty else {
            await coordinator.releasePrewarmSession(reason: "empty-capture")
            return .noSpeech
        }
        guard services.activeProviderRouter.isModelReady else {
            await coordinator.releasePrewarmSession(reason: "dictation-model-unavailable")
            return .failed
        }

        services.activeProviderRouter.warmup()
        let classification = stoppedCapture.classification
        let useDictionaryHintPrompt = DictionaryHintPromptGate.shouldUseHintPrompt(
            lastCaptureHadActiveSignal: classification.hadActiveSignal,
            lastCaptureWasLikelySilence: classification.shouldRejectLikelySilence,
            lastCaptureWasLongTrueSilence: classification.isLongTrueSilence,
            lastCaptureDuration: stoppedCapture.captureDuration,
            maxActiveSignalRunDuration: stoppedCapture.maxActiveSignalRunDuration
        )
        let dictationPipeline = await resolvedDictationPipeline()
        let result = await withCheckedContinuation { continuation in
            dictationPipeline.run(
                audioFrames: stoppedCapture.outputFrames,
                useDictionaryHintPrompt: useDictionaryHintPrompt,
                utteranceID: utteranceID
            ) { result in
                continuation.resume(returning: result)
            }
        }
        guard utteranceID == activeUtteranceID else {
            await coordinator.releasePrewarmSession(reason: "stale-result")
            return .pending
        }

        let finalText = result.finalText
        coordinator.recordLatestArtifact(from: result, selectedText: finalText)
        await coordinator.releasePrewarmSession(reason: "utterance-finished")

        guard !result.wasLikelyNoSpeech,
              !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .noSpeech
        }

        KeyVoxIPCBridge.setTranscription(
            finalText,
            id: result.id,
            styleIdentifier: result.textTransformationStyleIdentifier
        )
        return .transcript(finalText)
    }

    private func selectVibe(_ styleIdentifier: String?) {
        services.selectedVibe.style = styleIdentifier.flatMap(StyleRewriteStyle.init(rawValue:)) ?? .none
    }
}
