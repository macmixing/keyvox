import Foundation
import KeyVoxWhisper

extension WhisperService {
    func transcribeChunkWithLeadingPhraseRetry(
        chunkFrames: [Float],
        usedDictionaryHintPrompt: Bool
    ) async throws -> WhisperTranscriptionResult {
        let primary = try await whisper?.transcribeWithMetadata(audioFrames: chunkFrames) ?? WhisperTranscriptionResult(segments: [], detectedLanguageCode: nil, detectedLanguageName: nil)
        let shouldRetryEmptyResult = shouldRetryEmptyChunkDecode(primary.segments, chunkFrames: chunkFrames)
        let shouldRetryLeadingShort = shouldRetryLeadingPhraseDecode(
            primary.segments,
            chunkFrames: chunkFrames,
            usedDictionaryHintPrompt: usedDictionaryHintPrompt
        )
        let shouldRetryTrailingCutoff = shouldRetryTrailingCutoffDecode(
            primary.segments,
            chunkFrames: chunkFrames
        )
        guard shouldRetryEmptyResult || shouldRetryLeadingShort || shouldRetryTrailingCutoff else {
            return primary
        }
        guard let whisper else { return primary }

        let params = whisper.params
        let originalPrompt = params.initialPrompt
        let originalSuppressBlank = params.suppress_blank
        let originalLogprobThreshold = params.logprob_thold

        params.initialPrompt = ""
        params.suppress_blank = false
        params.logprob_thold = retryRelaxedLogprobThreshold

        defer {
            params.initialPrompt = originalPrompt
            params.suppress_blank = originalSuppressBlank
            params.logprob_thold = originalLogprobThreshold
        }

        #if DEBUG
        let duration = Double(chunkFrames.count) / 16_000.0
        let retryReason: String = {
            if shouldRetryEmptyResult && shouldRetryLeadingShort {
                return "empty_and_leading_short_result"
            }
            if shouldRetryEmptyResult {
                return "empty_chunk_result"
            }
            if shouldRetryTrailingCutoff {
                return "trailing_cutoff_result"
            }
            return "leading_short_result"
        }()
        print(
            "WhisperService retry: reason=\(retryReason) " +
            "chunkSeconds=\(String(format: "%.2f", duration)) " +
            "primaryWords=\(wordCount(in: compactSegmentText(primary.segments)))"
        )
        #endif

        let retry = try await whisper.transcribeWithMetadata(audioFrames: chunkFrames)
        let selection = selectPreferredRetry(
            primary: primary.segments,
            retry: retry.segments,
            acceptsSingleWordRecovery: shouldRetryTrailingCutoff
        )
        #if DEBUG
        let primaryText = compactSegmentText(primary.segments)
        let retryText = compactSegmentText(retry.segments)
        let primaryAverageNoSpeechProbability: Float = primary.segments.isEmpty
            ? 1.0
            : primary.segments.reduce(0) { $0 + $1.noSpeechProbability } / Float(primary.segments.count)
        let retryAverageNoSpeechProbability: Float = retry.segments.isEmpty
            ? 1.0
            : retry.segments.reduce(0) { $0 + $1.noSpeechProbability } / Float(retry.segments.count)
        print(
            "WhisperService retry selection: selected=\(selection.selectedRetry ? "retry" : "primary") " +
            "primaryWords=\(wordCount(in: primaryText)) primaryChars=\(primaryText.count) " +
            "primaryAvgNoSpeech=\(String(format: "%.3f", primaryAverageNoSpeechProbability)) " +
            "retryWords=\(wordCount(in: retryText)) retryChars=\(retryText.count) " +
            "retryAvgNoSpeech=\(String(format: "%.3f", retryAverageNoSpeechProbability)) " +
            "primaryText=\(primaryText) retryText=\(retryText)"
        )
        #endif
        let finalSegments = selection.segments
        let finalLanguageCode = selection.selectedRetry
            ? (retry.detectedLanguageCode ?? primary.detectedLanguageCode)
            : (primary.detectedLanguageCode ?? retry.detectedLanguageCode)
        let finalLanguageName = selection.selectedRetry
            ? (retry.detectedLanguageName ?? primary.detectedLanguageName)
            : (primary.detectedLanguageName ?? retry.detectedLanguageName)

        return WhisperTranscriptionResult(
            segments: finalSegments,
            detectedLanguageCode: finalLanguageCode,
            detectedLanguageName: finalLanguageName
        )
    }

    private func shouldRetryLeadingPhraseDecode(
        _ primary: [Segment],
        chunkFrames: [Float],
        usedDictionaryHintPrompt: Bool
    ) -> Bool {
        guard usedDictionaryHintPrompt else { return false }
        let duration = Double(chunkFrames.count) / 16_000.0
        guard duration >= suspiciousShortResultMinChunkSeconds else { return false }

        let compactText = compactSegmentText(primary)
        let words = wordCount(in: compactText)
        let isSuspiciousShortResult = isSuspiciouslyShortResult(words: words, chunkSeconds: duration)
        guard isSuspiciousShortResult else { return false }

        let averageNoSpeechProbability: Float
        if primary.isEmpty {
            averageNoSpeechProbability = 1.0
        } else {
            averageNoSpeechProbability = primary.reduce(0) { $0 + $1.noSpeechProbability } / Float(primary.count)
        }
        guard averageNoSpeechProbability <= suspiciousShortResultMaxNoSpeechProbability else { return false }

        return true
    }

    private func shouldRetryEmptyChunkDecode(
        _ primary: [Segment],
        chunkFrames: [Float]
    ) -> Bool {
        let duration = Double(chunkFrames.count) / 16_000.0
        return shouldRetryEmptyChunkResult(segmentCount: primary.count, chunkSeconds: duration)
    }

    private func shouldRetryTrailingCutoffDecode(
        _ primary: [Segment],
        chunkFrames: [Float]
    ) -> Bool {
        guard let lastSegment = primary.max(by: { $0.endTime < $1.endTime }) else { return false }

        let trailingStartFrame = min(
            max(Int((Double(lastSegment.endTime) / 1_000.0) * 16_000.0), 0),
            chunkFrames.count
        )
        let trailingFrames = Array(chunkFrames[trailingStartFrame..<chunkFrames.count])
        let duration = Double(chunkFrames.count) / 16_000.0
        return shouldRetryTrailingCutoffResult(
            segments: primary,
            chunkSeconds: duration,
            trailingAudioFrames: trailingFrames
        )
    }

    func isSuspiciouslyShortResult(words: Int, chunkSeconds: Double) -> Bool {
        guard words > 0 else { return false }
        if words <= suspiciousShortResultMaxWords {
            return true
        }
        guard chunkSeconds >= suspiciousShortResultDensityMinChunkSeconds else { return false }
        let wordsPerSecond = Double(words) / chunkSeconds
        return wordsPerSecond <= suspiciousShortResultMaxWordsPerSecond
    }

    func shouldRetryEmptyChunkResult(segmentCount: Int, chunkSeconds: Double) -> Bool {
        guard segmentCount == 0 else { return false }
        return chunkSeconds >= emptyResultRetryMinChunkSeconds
    }

    func shouldRetryTrailingCutoffResult(
        segments: [Segment],
        chunkSeconds: Double,
        trailingAudioFrames: [Float]
    ) -> Bool {
        guard chunkSeconds >= AudioSilenceGatePolicy.longCaptureMinimumDuration else { return false }
        guard !segments.isEmpty else { return false }
        guard trailingAudioContainsSpeechSignal(trailingAudioFrames) else { return false }

        let averageNoSpeechProbability = segments.reduce(0) { $0 + $1.noSpeechProbability } / Float(segments.count)
        return averageNoSpeechProbability <= suspiciousShortResultMaxNoSpeechProbability
    }

    func trailingAudioContainsSpeechSignal(_ audioFrames: [Float]) -> Bool {
        guard audioFrames.count >= AudioSilenceGatePolicy.trueSilenceWindowSize else { return false }

        let silentWindowRatio = AudioSilenceGatePolicy.trueSilenceWindowRatio(for: audioFrames)
        guard silentWindowRatio < AudioSilenceGatePolicy.trueSilenceMinimumWindowRatio else { return false }

        return AudioSignalMetrics.rms(of: audioFrames) >= AudioSilenceGatePolicy.trueSilenceWindowRMSThreshold
    }

    func selectPreferredRetry(
        primary: [Segment],
        retry: [Segment],
        acceptsSingleWordRecovery: Bool = false
    ) -> (segments: [Segment], selectedRetry: Bool) {
        let primaryText = compactSegmentText(primary)
        let retryText = compactSegmentText(retry)

        let primaryWords = wordCount(in: primaryText)
        let retryWords = wordCount(in: retryText)

        if acceptsSingleWordRecovery && retryWords > primaryWords {
            return (retry, true)
        }
        if retryWords >= primaryWords + 2 {
            return (retry, true)
        }
        if retryWords == primaryWords && retryText.count >= primaryText.count + 12 {
            return (retry, true)
        }
        return (primary, false)
    }

    private func compactSegmentText(_ segments: [Segment]) -> String {
        let joinedText = segments
            .map { $0.text }
            .joined(separator: " ")
        return normalizeWhitespace(joinedText)
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
