import Foundation
import KeyVoxParakeet

extension ParakeetService {
    struct TranscribedChunk {
        let text: String
        let trailingBoundaryFrame: Int?
    }

    public func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        let requestID = beginTranscriptionRequest()
        transcriptionTask?.cancel()
        transcriptionTask = nil

        guard !audioFrames.isEmpty else {
            finishEmptyRequest(requestID, completion: completion)
            return
        }

        isTranscribing = true
        lastResultWasLikelyNoSpeech = false

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            guard let parakeet = await self.loadedParakeet() else {
                self.finishFailedRequest(requestID, completion: completion)
                return
            }

            if useDictionaryHintPrompt {
                parakeet.params.initialPrompt = self.dictionaryHintPrompt
            } else {
                parakeet.params.initialPrompt = ""
            }

            let paragraphChunker = self.paragraphChunker

            do {
                let chunkResult = paragraphChunker.split(audioFrames)
                var transcribedChunks: [TranscribedChunk] = []
                transcribedChunks.reserveCapacity(chunkResult.chunks.count)
                var transcribedResult = ParakeetTranscriptionResult(segments: [])
                var chunkSegmentCounts: [Int] = []
                chunkSegmentCounts.reserveCapacity(chunkResult.chunks.count)
                var detectedLanguageCode: String?

                for (chunkIndex, chunk) in chunkResult.chunks.enumerated() {
                    if Task.isCancelled {
                        self.finishCancelledRequest(requestID)
                        return
                    }

                    let chunkFrames = Array(audioFrames[chunk.startFrame..<chunk.endFrame])
                    guard !chunkFrames.isEmpty else { continue }

                    let result = try await parakeet.transcribeWithMetadata(audioFrames: chunkFrames)
                    if detectedLanguageCode == nil {
                        detectedLanguageCode = result.detectedLanguageCode
                    }
                    transcribedResult = ParakeetTranscriptionResult(
                        segments: transcribedResult.segments + result.segments,
                        detectedLanguageCode: detectedLanguageCode ?? result.detectedLanguageCode,
                        detectedLanguageName: result.detectedLanguageName
                    )
                    chunkSegmentCounts.append(result.segments.count)

                    let chunkText = result.segments
                        .map(\.text)
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
                }

                if Task.isCancelled {
                    self.finishCancelledRequest(requestID)
                    return
                }

                let originalSegmentCount = transcribedResult.segments.count
                let filteredResult = ParakeetUtteranceGate.droppingLikelyNoSpeechTrailingSegments(
                    from: transcribedResult
                )
                let droppedTrailingSegmentCount = originalSegmentCount - filteredResult.segments.count
                if droppedTrailingSegmentCount > 0,
                   !transcribedChunks.isEmpty,
                   !chunkSegmentCounts.isEmpty {
                    let priorSegmentCount = chunkSegmentCounts.dropLast().reduce(0, +)
                    let remainingLastChunkSegments = max(0, filteredResult.segments.count - priorSegmentCount)
                    let filteredLastChunkSegments = Array(filteredResult.segments.suffix(remainingLastChunkSegments))
                    transcribedChunks[transcribedChunks.count - 1] = TranscribedChunk(
                        text: self.normalizeWhitespace(filteredLastChunkSegments.map(\.text).joined(separator: " ")),
                        trailingBoundaryFrame: transcribedChunks[transcribedChunks.count - 1].trailingBoundaryFrame
                    )
                }

                let assembledText = self.assembleTranscription(
                    from: transcribedChunks,
                    silenceBoundaryFrames: Set(chunkResult.silenceBoundaryFrames),
                    enableAutoParagraphs: enableAutoParagraphs
                )
                let finalText = self.normalizeWhitespace(
                    assembledText,
                    preservingNewlines: enableAutoParagraphs
                )
                let likelyNoSpeech = finalText.isEmpty || self.isLikelyNoSpeech(
                    transcribedSegments: filteredResult.segments,
                    audioFrameCount: audioFrames.count
                )
                #if DEBUG
                let averageConfidence: Float = filteredResult.segments.isEmpty
                    ? 0
                    : filteredResult.segments.compactMap(\.confidence).reduce(0, +) / Float(max(filteredResult.segments.compactMap(\.confidence).count, 1))
                let averageNoSpeechProbability: Float = filteredResult.segments.compactMap(\.noSpeechProbability).isEmpty
                    ? 0
                    : filteredResult.segments.compactMap(\.noSpeechProbability).reduce(0, +) / Float(max(filteredResult.segments.compactMap(\.noSpeechProbability).count, 1))
                let nonEmptySegments = filteredResult.segments.filter {
                    !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                let utteranceDurationSeconds = self.utteranceDurationSeconds(
                    for: nonEmptySegments,
                    fallbackAudioFrameCount: audioFrames.count
                )
                print(
                    "ParakeetService final decode: chunks=\(chunkResult.chunks.count) " +
                    "segments=\(filteredResult.segments.count) " +
                    "droppedTrailingSegments=\(droppedTrailingSegmentCount) " +
                    "audioSeconds=\(String(format: "%.2f", Double(audioFrames.count) / 16_000.0)) " +
                    "utteranceSeconds=\(String(format: "%.2f", utteranceDurationSeconds)) " +
                    "avgConfidence=\(String(format: "%.3f", averageConfidence)) " +
                    "avgNoSpeechProb=\(String(format: "%.3f", averageNoSpeechProbability)) " +
                    "likelyNoSpeech=\(likelyNoSpeech) " +
                    "finalChars=\(finalText.count)"
                )
                #endif
                self.finishSuccessfulRequest(
                    requestID,
                    finalText: likelyNoSpeech ? "" : finalText,
                    likelyNoSpeech: likelyNoSpeech,
                    detectedLanguageCode: detectedLanguageCode,
                    completion: completion
                )
            } catch let error as ParakeetError {
                if case .cancelled = error {
                    self.finishCancelledRequest(requestID)
                    return
                }
                self.finishFailedRequest(requestID, completion: completion)
            } catch {
                if Task.isCancelled {
                    self.finishCancelledRequest(requestID)
                    return
                }
                self.finishFailedRequest(requestID, completion: completion)
            }
        }
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
        guard preservingNewlines else {
            return text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let normalizedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                String(line)
                    .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
        }
        return normalizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isLikelyNoSpeech(
        transcribedSegments: [ParakeetSegment],
        audioFrameCount: Int
    ) -> Bool {
        ParakeetUtteranceGate.isLikelyNoSpeech(
            result: ParakeetTranscriptionResult(
                segments: transcribedSegments,
                detectedLanguageCode: nil,
                detectedLanguageName: nil
            ),
            audioFrameCount: audioFrameCount
        )
    }

    func utteranceDurationSeconds(
        for nonEmptySegments: [ParakeetSegment],
        fallbackAudioFrameCount: Int
    ) -> Double {
        ParakeetUtteranceGate.utteranceDurationSeconds(
            for: nonEmptySegments,
            fallbackAudioFrameCount: fallbackAudioFrameCount
        )
    }
}
