import Foundation

public protocol TextTransformTokenCounting: Sendable {
    func tokenCount(for text: String) async throws -> Int
}

public struct ApproximateTextTransformTokenCounter: TextTransformTokenCounting {
    public init() {}

    public func tokenCount(for text: String) async throws -> Int {
        Self.estimatedTokenCount(for: text)
    }

    static func estimatedTokenCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, Int(ceil(Double(text.count) / 4.0)))
    }
}

public struct TextTransformChunk: Equatable, Sendable {
    public let index: Int
    public let text: String
    public let separatorAfter: String
    public let inputTokenCount: Int

    public init(index: Int, text: String, separatorAfter: String, inputTokenCount: Int) {
        self.index = index
        self.text = text
        self.separatorAfter = separatorAfter
        self.inputTokenCount = inputTokenCount
    }
}

public struct TextTransformChunkPlan: Equatable, Sendable {
    public let chunks: [TextTransformChunk]
    public let promptOverheadTokenCount: Int
    public let maximumInputTokensPerChunk: Int

    public init(
        chunks: [TextTransformChunk],
        promptOverheadTokenCount: Int,
        maximumInputTokensPerChunk: Int
    ) {
        self.chunks = chunks
        self.promptOverheadTokenCount = promptOverheadTokenCount
        self.maximumInputTokensPerChunk = maximumInputTokensPerChunk
    }
}

@MainActor
public protocol TextTransformChunkResponding: AnyObject {
    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String
}

@MainActor
public final class TextTransformChunkRunner {
    private let planner: TextTransformChunkPlanner
    private let responder: any TextTransformChunkResponding

    public init(
        planner: TextTransformChunkPlanner,
        responder: any TextTransformChunkResponding
    ) {
        self.planner = planner
        self.responder = responder
    }

    public func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        let transformStart = Date()
        guard !request.baseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return TextTransformResult.fallback(request: request, duration: 0, errors: [])
        }

        let chunkPlan = await planner.planChunks(for: request)
        guard !chunkPlan.chunks.isEmpty else {
            return TextTransformResult.fallback(request: request, duration: 0, errors: [])
        }

        var output = ""
        var timings: [TextTransformChunkTiming] = []
        var errors: [TextTransformErrorSummary] = []

        for chunk in chunkPlan.chunks {
            let chunkStart = Date()

            do {
                let transformedText = try await responder
                    .transformChunk(chunk, request: request)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let chunkOutput = transformedText.isEmpty ? chunk.text : transformedText
                let usedFallbackText = transformedText.isEmpty
                output += chunkOutput + chunk.separatorAfter
                if usedFallbackText {
                    errors.append(TextTransformErrorSummary(
                        chunkIndex: chunk.index,
                        message: "emptyResponse",
                        errorCode: .emptyResponse
                    ))
                }
                timings.append(TextTransformChunkTiming(
                    chunkIndex: chunk.index,
                    inputTokenCount: chunk.inputTokenCount,
                    duration: Date().timeIntervalSince(chunkStart),
                    usedFallbackText: usedFallbackText
                ))
            } catch let error as StyleRewriteBackendError {
                output += chunk.text + chunk.separatorAfter
                errors.append(TextTransformErrorSummary(
                    chunkIndex: chunk.index,
                    message: String(describing: error),
                    errorCode: error.errorCode
                ))
                timings.append(TextTransformChunkTiming(
                    chunkIndex: chunk.index,
                    inputTokenCount: chunk.inputTokenCount,
                    duration: Date().timeIntervalSince(chunkStart),
                    usedFallbackText: true
                ))
            } catch {
                output += chunk.text + chunk.separatorAfter
                errors.append(TextTransformErrorSummary(
                    chunkIndex: chunk.index,
                    message: String(describing: error),
                    errorCode: .generationFailed
                ))
                timings.append(TextTransformChunkTiming(
                    chunkIndex: chunk.index,
                    inputTokenCount: chunk.inputTokenCount,
                    duration: Date().timeIntervalSince(chunkStart),
                    usedFallbackText: true
                ))
            }
        }

        return TextTransformResult(
            originalText: request.baseText,
            finalText: output,
            styleIdentifier: request.styleIdentifier,
            duration: Date().timeIntervalSince(transformStart),
            chunkCount: chunkPlan.chunks.count,
            applied: output != request.baseText && errors.count < chunkPlan.chunks.count,
            chunkTimings: timings,
            errors: errors
        )
    }
}

public struct TextTransformChunkPlanner: Sendable {
    private struct Segment: Sendable {
        let text: String
        let separatorAfter: String
    }

    private let tokenCounter: any TextTransformTokenCounting

    public init(tokenCounter: any TextTransformTokenCounting = ApproximateTextTransformTokenCounter()) {
        self.tokenCounter = tokenCounter
    }

    public func planChunks(for request: TextTransformRequest) async -> TextTransformChunkPlan {
        let promptOverhead = await tokenCount(
            for: [request.instructions, request.promptPrefix, request.promptSuffix].joined(separator: "\n")
        )
        let maximumInputTokens = maximumInputTokensPerChunk(
            request: request,
            promptOverheadTokenCount: promptOverhead
        )
        let segments = semanticSegments(in: request.baseText)
        let chunks = await chunks(from: segments, maximumInputTokens: maximumInputTokens)

        return TextTransformChunkPlan(
            chunks: chunks,
            promptOverheadTokenCount: promptOverhead,
            maximumInputTokensPerChunk: maximumInputTokens
        )
    }

    private func maximumInputTokensPerChunk(
        request: TextTransformRequest,
        promptOverheadTokenCount: Int
    ) -> Int {
        let usableContextTokenCount = max(
            1,
            request.contextTokenLimit - promptOverheadTokenCount - request.safetyMarginTokens
        )
        let outputExpansionRatio = max(request.expectedOutputExpansionRatio, 1.0)
        let contextLimitedInputTokens = max(
            1,
            Int(floor(Double(usableContextTokenCount) / (1.0 + outputExpansionRatio)))
        )

        guard let maximumResponseTokens = request.maximumResponseTokens else {
            return contextLimitedInputTokens
        }

        let responseLimitedInputTokens = max(
            1,
            Int(floor(Double(max(maximumResponseTokens - 16, 1)) / outputExpansionRatio))
        )
        return min(contextLimitedInputTokens, responseLimitedInputTokens)
    }

    private func chunks(
        from segments: [Segment],
        maximumInputTokens: Int
    ) async -> [TextTransformChunk] {
        var chunks: [TextTransformChunk] = []
        var currentText = ""
        var currentSeparator = ""
        var currentTokens = 0

        for segment in segments {
            let segmentTokens = await tokenCount(for: segment.text)
            if currentText.isEmpty {
                if segmentTokens <= maximumInputTokens {
                    currentText = segment.text
                    currentSeparator = segment.separatorAfter
                    currentTokens = segmentTokens
                } else {
                    chunks.append(contentsOf: await wordChunks(
                        from: segment,
                        startingAt: chunks.count,
                        maximumInputTokens: maximumInputTokens
                    ))
                }
                continue
            }

            if currentTokens + segmentTokens <= maximumInputTokens {
                currentText += currentSeparator + segment.text
                currentSeparator = segment.separatorAfter
                currentTokens += segmentTokens
            } else {
                chunks.append(TextTransformChunk(
                    index: chunks.count,
                    text: currentText,
                    separatorAfter: currentSeparator,
                    inputTokenCount: currentTokens
                ))
                currentText = ""
                currentSeparator = ""
                currentTokens = 0

                if segmentTokens <= maximumInputTokens {
                    currentText = segment.text
                    currentSeparator = segment.separatorAfter
                    currentTokens = segmentTokens
                } else {
                    chunks.append(contentsOf: await wordChunks(
                        from: segment,
                        startingAt: chunks.count,
                        maximumInputTokens: maximumInputTokens
                    ))
                }
            }
        }

        if !currentText.isEmpty {
            chunks.append(TextTransformChunk(
                index: chunks.count,
                text: currentText,
                separatorAfter: currentSeparator,
                inputTokenCount: currentTokens
            ))
        }

        return chunks
    }

    private func wordChunks(
        from segment: Segment,
        startingAt startIndex: Int,
        maximumInputTokens: Int
    ) async -> [TextTransformChunk] {
        let words = wordSegments(in: segment.text, finalSeparator: segment.separatorAfter)
        var chunks: [TextTransformChunk] = []
        var currentText = ""
        var currentSeparator = ""
        var currentTokens = 0

        for word in words {
            let wordTokens = await tokenCount(for: word.text)
            if currentText.isEmpty {
                currentText = word.text
                currentSeparator = word.separatorAfter
                currentTokens = wordTokens
                continue
            }

            if currentTokens + wordTokens <= maximumInputTokens {
                currentText += currentSeparator + word.text
                currentSeparator = word.separatorAfter
                currentTokens += wordTokens
            } else {
                chunks.append(TextTransformChunk(
                    index: startIndex + chunks.count,
                    text: currentText,
                    separatorAfter: currentSeparator,
                    inputTokenCount: currentTokens
                ))
                currentText = word.text
                currentSeparator = word.separatorAfter
                currentTokens = wordTokens
            }
        }

        if !currentText.isEmpty {
            chunks.append(TextTransformChunk(
                index: startIndex + chunks.count,
                text: currentText,
                separatorAfter: currentSeparator,
                inputTokenCount: currentTokens
            ))
        }

        return chunks
    }

    private func tokenCount(for text: String) async -> Int {
        do {
            return try await tokenCounter.tokenCount(for: text)
        } catch {
            return ApproximateTextTransformTokenCounter.estimatedTokenCount(for: text)
        }
    }

    private func semanticSegments(in text: String) -> [Segment] {
        var segments: [Segment] = []
        var current = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\n" {
                let separator = consumeSeparator(in: text, startingAt: index)
                if !current.isEmpty {
                    segments.append(Segment(text: current, separatorAfter: separator.value))
                    current = ""
                }
                index = separator.endIndex
                continue
            }

            current.append(character)

            if isSentenceBoundary(character) {
                let next = text.index(after: index)
                let separator = consumeSeparator(in: text, startingAt: next)
                if !separator.value.isEmpty {
                    segments.append(Segment(text: current, separatorAfter: separator.value))
                    current = ""
                    index = separator.endIndex
                    continue
                }
            }

            index = text.index(after: index)
        }

        if !current.isEmpty {
            segments.append(Segment(text: current, separatorAfter: ""))
        }

        return segments
    }

    private func wordSegments(in text: String, finalSeparator: String) -> [Segment] {
        var segments: [Segment] = []
        var current = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                let separator = consumeSeparator(in: text, startingAt: index)
                if !current.isEmpty {
                    segments.append(Segment(text: current, separatorAfter: separator.value))
                    current = ""
                }
                index = separator.endIndex
                continue
            }

            current.append(character)
            index = text.index(after: index)
        }

        if !current.isEmpty {
            segments.append(Segment(text: current, separatorAfter: finalSeparator))
        }

        return segments
    }

    private func consumeSeparator(
        in text: String,
        startingAt startIndex: String.Index
    ) -> (value: String, endIndex: String.Index) {
        var separator = ""
        var index = startIndex

        while index < text.endIndex {
            let character = text[index]
            guard character.isWhitespace else { break }
            separator.append(character)
            index = text.index(after: index)
        }

        return (separator, index)
    }

    private func isSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?"
    }
}
