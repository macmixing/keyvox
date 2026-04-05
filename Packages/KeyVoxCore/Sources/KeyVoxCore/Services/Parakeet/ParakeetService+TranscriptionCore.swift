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
                var transcribedSegments: [ParakeetSegment] = []
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
                    transcribedSegments.append(contentsOf: result.segments)

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
                    transcribedSegments: transcribedSegments,
                    detectedLanguageCode: detectedLanguageCode,
                    audioFrameCount: audioFrames.count
                )
                #if DEBUG
                let averageConfidence: Float = transcribedSegments.isEmpty
                    ? 0
                    : transcribedSegments.compactMap(\.confidence).reduce(0, +) / Float(max(transcribedSegments.compactMap(\.confidence).count, 1))
                print(
                    "ParakeetService final decode: chunks=\(chunkResult.chunks.count) " +
                    "segments=\(transcribedSegments.count) " +
                    "audioSeconds=\(String(format: "%.2f", Double(audioFrames.count) / 16_000.0)) " +
                    "avgConfidence=\(String(format: "%.3f", averageConfidence)) " +
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
        detectedLanguageCode: String?,
        audioFrameCount: Int
    ) -> Bool {
        ParakeetUtteranceGate.isLikelyNoSpeech(
            result: ParakeetTranscriptionResult(
                segments: transcribedSegments,
                detectedLanguageCode: detectedLanguageCode,
                detectedLanguageName: nil
            ),
            audioFrameCount: audioFrameCount
        )
    }
}
