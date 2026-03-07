import Foundation
import AVFoundation
import KeyVoxWhisper

extension WhisperService {
    public func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool = true,
        enableAutoParagraphs: Bool = true,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        // Hardening: ensure only one transcription runs at a time
        transcriptionTask?.cancel()
        transcriptionTask = nil
        guard !audioFrames.isEmpty else {
            #if DEBUG
            print("Skipping transcription: audio buffer is empty or silent.")
            #endif
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.lastResultWasLikelyNoSpeech = true
                self.transcriptionText = ""
                completion(TranscriptionProviderResult(text: "", languageCode: nil))
            }
            return
        }

        self.isTranscribing = true
        self.lastResultWasLikelyNoSpeech = false

        // Ensure model is loaded (if warmup wasn't called/finished)
        if whisper == nil {
            warmup()
        }

        let shouldUseDictionaryHintPrompt = isPromptHintingEnabled && useDictionaryHintPrompt

        if shouldUseDictionaryHintPrompt {
            whisper?.params.initialPrompt = dictionaryHintPrompt
        } else {
            whisper?.params.initialPrompt = ""
            #if DEBUG
            let hintReason = isPromptHintingEnabled ? "capture_gated_off" : "globally_disabled"
            print("WhisperService: Dictionary hint prompt not used (\(hintReason)).")
            #endif
        }

        let restoreDictionaryHintPromptIfNeeded = { [weak self] in
            guard let self, !shouldUseDictionaryHintPrompt else { return }
            self.whisper?.params.initialPrompt = self.isPromptHintingEnabled ? self.dictionaryHintPrompt : ""
        }

        #if DEBUG
        print("Transcribing \(audioFrames.count) raw frames...")
        #endif

        transcriptionTask = Task {
            do {
                let chunkResult = self.paragraphChunker.split(audioFrames)
                #if DEBUG
                let boundaryMs = chunkResult.boundaryFrames.map { Int((Double($0) / 16_000.0) * 1_000.0) }
                let chunkDurationsMs = chunkResult.chunkFrameLengths.map { Int((Double($0) / 16_000.0) * 1_000.0) }
                print(
                    "WhisperService chunking: chunks=\(chunkResult.chunks.count) " +
                    "boundariesMs=\(boundaryMs) " +
                    "silenceBoundaryCount=\(chunkResult.silenceBoundaryFrames.count) " +
                    "fallbackBoundaryCount=\(chunkResult.fallbackBoundaryFrames.count) " +
                    "chunkDurationsMs=\(chunkDurationsMs) " +
                    "maxChunkMs=\(Int((Double(chunkResult.maxChunkFrames) / 16_000.0) * 1_000.0)) " +
                    "silenceThreshold=\(String(format: "%.5f", chunkResult.silenceThreshold))"
                )
                #endif

                var transcribedSegments: [Segment] = []
                var chunkTexts: [String] = []
                var detectedLanguageCode: String? = nil
                var nonEmptyChunkTextCount = 0

                for (chunkIndex, chunk) in chunkResult.chunks.enumerated() {
                    if Task.isCancelled {
                        DispatchQueue.main.async {
                            self.isTranscribing = false
                            restoreDictionaryHintPromptIfNeeded()
                        }
                        return
                    }

                    let chunkFrames = Array(audioFrames[chunk.startFrame..<chunk.endFrame])
                    guard !chunkFrames.isEmpty else { continue }

                    let result = try await self.transcribeChunkWithLeadingPhraseRetry(
                        chunkFrames: chunkFrames,
                        usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt
                    )
                    let segments = result.segments
                    if detectedLanguageCode == nil {
                        detectedLanguageCode = result.detectedLanguageCode
                    }
                    #if DEBUG
                    logChunkSegments(segments, chunkIndex: chunkIndex, totalChunks: chunkResult.chunks.count)
                    #endif
                    transcribedSegments.append(contentsOf: segments)
                    let chunkText = segments
                        .map { $0.text }
                        .joined(separator: " ")
                    let normalizedChunkText = normalizeWhitespace(chunkText)
                    if !normalizedChunkText.isEmpty {
                        chunkTexts.append(normalizedChunkText)
                        nonEmptyChunkTextCount += 1
                    }
                    #if DEBUG
                    let chunkDurationSeconds = Double(chunk.endFrame - chunk.startFrame) / 16_000.0
                    let averageChunkNoSpeechProbability: Float = segments.isEmpty
                        ? 1.0
                        : (segments.reduce(0) { $0 + $1.noSpeechProbability } / Float(segments.count))
                    print(
                        "WhisperService chunk result: chunk=\(chunkIndex + 1)/\(chunkResult.chunks.count) " +
                        "seconds=\(String(format: "%.2f", chunkDurationSeconds)) " +
                        "segments=\(segments.count) " +
                        "avgNoSpeech=\(String(format: "%.3f", averageChunkNoSpeechProbability)) " +
                        "emptyText=\(normalizedChunkText.isEmpty)"
                    )
                    #endif
                }

                // Check if task was cancelled before proceeding
                if Task.isCancelled {
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        restoreDictionaryHintPromptIfNeeded()
                    }
                    return
                }

                let paragraphSeparator = enableAutoParagraphs ? "\n\n" : " "
                let text = chunkTexts
                    .joined(separator: paragraphSeparator)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let hasSegments = !transcribedSegments.isEmpty
                let allSegmentsHighNoSpeech = hasSegments && transcribedSegments.allSatisfy {
                    $0.noSpeechProbability >= self.noSpeechSegmentProbabilityThreshold
                }
                let averageNoSpeechProbability: Float = hasSegments
                    ? transcribedSegments.reduce(0) { $0 + $1.noSpeechProbability } / Float(transcribedSegments.count)
                    : 1.0
                let likelyNoSpeechByDecoder = !hasSegments
                    || allSegmentsHighNoSpeech
                    || averageNoSpeechProbability >= self.noSpeechAverageProbabilityThreshold

                let cleanedText = self.normalizeWhitespace(text, preservingNewlines: true)
                let finalText = likelyNoSpeechByDecoder ? "" : cleanedText
                #if DEBUG
                print(
                    "WhisperService paragraphing: segments=\(transcribedSegments.count) " +
                    "enabled=\(enableAutoParagraphs) " +
                    "hasParagraphBreaks=\(finalText.contains("\n\n"))"
                )
                print(
                    "WhisperService final decode: totalChunks=\(chunkResult.chunks.count) " +
                    "nonEmptyChunks=\(nonEmptyChunkTextCount) " +
                    "segments=\(transcribedSegments.count) " +
                    "likelyNoSpeech=\(likelyNoSpeechByDecoder) " +
                    "finalChars=\(finalText.count)"
                )
                #endif

                DispatchQueue.main.async {
                    self.isTranscribing = false
                    restoreDictionaryHintPromptIfNeeded()
                    self.lastResultWasLikelyNoSpeech = likelyNoSpeechByDecoder
                    self.transcriptionText = finalText
                    completion(TranscriptionProviderResult(text: finalText, languageCode: detectedLanguageCode))
                }
            } catch {
                if Task.isCancelled {
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        restoreDictionaryHintPromptIfNeeded()
                    }
                    return
                }

                #if DEBUG
                print("Transcription error: \(error)")
                #endif
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    restoreDictionaryHintPromptIfNeeded()
                    self.lastResultWasLikelyNoSpeech = false
                    completion(nil)
                }
            }
        }
    }

    // Legacy support for file-based transcription (can be removed later)
    public func transcribe(audioURL: URL, completion: @escaping (TranscriptionProviderResult?) -> Void) {
        Task {
            do {
                let audioFrames = try loadAndResample(url: audioURL)
                transcribe(audioFrames: audioFrames, enableAutoParagraphs: true, completion: completion)
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    private func loadAndResample(url: URL) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: url)
        let inputFormat = inputFile.processingFormat

        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"])
        }

        let ratio = 16000.0 / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputFile.length) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            throw NSError(domain: "WhisperService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inNumPackets)!
            do {
                try inputFile.read(into: inputBuffer)
                outStatus.pointee = .haveData
                return inputBuffer
            } catch {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            throw error ?? NSError(domain: "WhisperService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])
        }

        guard let floatData = outputBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
    }

    private func transcribeChunkWithLeadingPhraseRetry(
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
        guard shouldRetryEmptyResult || shouldRetryLeadingShort else {
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
            return "leading_short_result"
        }()
        print(
            "WhisperService retry: reason=\(retryReason) " +
            "chunkSeconds=\(String(format: "%.2f", duration)) " +
            "primaryWords=\(wordCount(in: compactSegmentText(primary.segments)))"
        )
        #endif

        let retry = try await whisper.transcribeWithMetadata(audioFrames: chunkFrames)
        let selection = selectPreferredRetry(primary: primary.segments, retry: retry.segments)
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

    private func selectPreferredRetry(
        primary: [Segment],
        retry: [Segment]
    ) -> (segments: [Segment], selectedRetry: Bool) {
        let primaryText = compactSegmentText(primary)
        let retryText = compactSegmentText(retry)

        let primaryWords = wordCount(in: primaryText)
        let retryWords = wordCount(in: retryText)

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

    private func normalizeWhitespace(_ text: String, preservingNewlines: Bool = false) -> String {
        guard !preservingNewlines else {
            let normalizedLines = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    String(line)
                        .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                }
            return normalizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    #if DEBUG
    private func logChunkSegments(_ segments: [Segment], chunkIndex: Int, totalChunks: Int) {
        guard !segments.isEmpty else {
            print("WhisperService segments: chunk=\(chunkIndex + 1)/\(totalChunks) count=0")
            return
        }
        let rawDebugTextLoggingEnabled = ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"

        let segmentSummaries = segments.prefix(3).enumerated().map { index, segment in
            let loggedText: String
            if rawDebugTextLoggingEnabled {
                let compactText = normalizeWhitespace(segment.text)
                loggedText = compactText.count > 80 ? String(compactText.prefix(80)) + "…" : compactText
            } else {
                loggedText = "<redacted>"
            }
            return
                "#\(index + 1){start=\(segment.startTime),end=\(segment.endTime),p=\(String(format: "%.3f", segment.noSpeechProbability)),text=\(loggedText)}"
        }.joined(separator: " ")

        print(
            "WhisperService segments: chunk=\(chunkIndex + 1)/\(totalChunks) count=\(segments.count) \(segmentSummaries)"
        )
    }
    #endif
}
