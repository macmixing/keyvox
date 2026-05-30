import Foundation
import AVFoundation
import KeyVoxWhisper

extension WhisperService {
    struct TranscribedChunk {
        let text: String
        let trailingBoundaryFrame: Int?
    }

    public func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool = true,
        enableAutoParagraphs: Bool = true,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        let requestID = beginTranscriptionRequest()
        transcriptionTask?.cancel()
        transcriptionTask = nil

        guard !audioFrames.isEmpty else {
            #if DEBUG
            print("Skipping transcription: audio buffer is empty or silent.")
            #endif
            finishEmptyRequest(requestID, completion: completion)
            return
        }

        isTranscribing = true
        lastResultWasLikelyNoSpeech = false

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

        #if DEBUG
        print("Transcribing \(audioFrames.count) raw frames...")
        #endif

        let paragraphChunker = self.paragraphChunker
        let noSpeechSegmentProbabilityThreshold = self.noSpeechSegmentProbabilityThreshold
        let noSpeechAverageProbabilityThreshold = self.noSpeechAverageProbabilityThreshold

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let chunkResult = paragraphChunker.split(audioFrames)
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
                var transcribedChunks: [TranscribedChunk] = []
                var detectedLanguageCode: String? = nil
                var nonEmptyChunkTextCount = 0

                for (chunkIndex, chunk) in chunkResult.chunks.enumerated() {
                    if Task.isCancelled {
                        self.finishCancelledRequest(
                            requestID,
                            usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt
                        )
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
                    self.logChunkSegments(segments, chunkIndex: chunkIndex, totalChunks: chunkResult.chunks.count)
                    #endif
                    transcribedSegments.append(contentsOf: segments)
                    let chunkText = segments
                        .map { $0.text }
                        .joined(separator: " ")
                    let normalizedChunkText = self.normalizeWhitespace(chunkText)
                    let trailingBoundaryFrame = chunkIndex < (chunkResult.chunks.count - 1)
                        ? chunk.endFrame
                        : nil
                    transcribedChunks.append(
                        TranscribedChunk(
                            text: normalizedChunkText,
                            trailingBoundaryFrame: trailingBoundaryFrame
                        )
                    )
                    if !normalizedChunkText.isEmpty {
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
                    self.finishCancelledRequest(
                        requestID,
                        usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt
                    )
                    return
                }

                let paragraphText = self.assembleTranscription(
                    from: transcribedChunks,
                    silenceBoundaryFrames: Set(chunkResult.silenceBoundaryFrames),
                    enableAutoParagraphs: true
                )
                let inlineText = self.assembleTranscription(
                    from: transcribedChunks,
                    silenceBoundaryFrames: Set(chunkResult.silenceBoundaryFrames),
                    enableAutoParagraphs: false
                )
                let hasSegments = !transcribedSegments.isEmpty
                let allSegmentsHighNoSpeech = hasSegments && transcribedSegments.allSatisfy {
                    $0.noSpeechProbability >= noSpeechSegmentProbabilityThreshold
                }
                let averageNoSpeechProbability: Float = hasSegments
                    ? transcribedSegments.reduce(0) { $0 + $1.noSpeechProbability } / Float(transcribedSegments.count)
                    : 1.0
                let likelyNoSpeechByDecoder = !hasSegments
                    || allSegmentsHighNoSpeech
                    || averageNoSpeechProbability >= noSpeechAverageProbabilityThreshold

                let cleanedParagraphText = self.normalizeWhitespace(paragraphText, preservingNewlines: true)
                let cleanedInlineText = self.normalizeWhitespace(inlineText)
                let selectedText = enableAutoParagraphs ? cleanedParagraphText : cleanedInlineText
                let finalText = likelyNoSpeechByDecoder ? "" : selectedText
                #if DEBUG
                print(
                    "WhisperService paragraphing: segments=\(transcribedSegments.count) " +
                    "enabled=\(enableAutoParagraphs) " +
                    "hasParagraphBreaks=\(cleanedParagraphText.contains("\n\n"))"
                )
                print(
                    "WhisperService final decode: totalChunks=\(chunkResult.chunks.count) " +
                    "nonEmptyChunks=\(nonEmptyChunkTextCount) " +
                    "segments=\(transcribedSegments.count) " +
                    "likelyNoSpeech=\(likelyNoSpeechByDecoder) " +
                    "finalChars=\(finalText.count)"
                )
                #endif

                self.finishSuccessfulRequest(
                    requestID,
                    usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt,
                    finalText: finalText,
                    paragraphsText: likelyNoSpeechByDecoder ? "" : cleanedParagraphText,
                    inlineText: likelyNoSpeechByDecoder ? "" : cleanedInlineText,
                    likelyNoSpeech: likelyNoSpeechByDecoder,
                    detectedLanguageCode: detectedLanguageCode,
                    completion: completion
                )
            } catch {
                if Task.isCancelled {
                    self.finishCancelledRequest(
                        requestID,
                        usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt
                    )
                    return
                }

                #if DEBUG
                print("Transcription error: \(error)")
                #endif
                self.finishFailedRequest(
                    requestID,
                    usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt,
                    completion: completion
                )
            }
        }
    }

    // Legacy support for file-based transcription (can be removed later)
    public func transcribe(audioURL: URL, completion: @escaping (TranscriptionProviderResult?) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let audioFrames = try self.loadAndResample(url: audioURL)
                self.transcribe(audioFrames: audioFrames, enableAutoParagraphs: true, completion: completion)
            } catch {
                completion(nil)
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

    func assembleTranscription(
        from chunks: [TranscribedChunk],
        silenceBoundaryFrames: Set<Int>,
        enableAutoParagraphs: Bool
    ) -> String {
        guard !chunks.isEmpty else { return "" }

        let punctuationNormalizer = TerminalPunctuationNormalizer()
        var assembled = ""
        var lastNonEmptyChunkIndex: Int?

        for (index, chunk) in chunks.enumerated() {
            guard !chunk.text.isEmpty else { continue }

            if let previousIndex = lastNonEmptyChunkIndex, !assembled.isEmpty {
                let sawSilenceBoundary = enableAutoParagraphs && chunks[previousIndex..<index].contains {
                    guard let boundaryFrame = $0.trailingBoundaryFrame else { return false }
                    return silenceBoundaryFrames.contains(boundaryFrame)
                }
                let separator = sawSilenceBoundary &&
                    punctuationNormalizer.hasTerminalSentencePunctuation(chunks[previousIndex].text)
                    ? "\n\n"
                    : " "
                assembled += separator
            }

            assembled += chunk.text
            lastNonEmptyChunkIndex = index
        }

        return assembled.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizeWhitespace(_ text: String, preservingNewlines: Bool = false) -> String {
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
