import Foundation

public struct StyleRewriteTextTransformTokenCounter: TextTransformTokenCounting {
    private let fallbackTokenCounter: any TextTransformTokenCounting

    public init(fallbackTokenCounter: any TextTransformTokenCounting = ApproximateTextTransformTokenCounter()) {
        self.fallbackTokenCounter = fallbackTokenCounter
    }

    public func tokenCount(for text: String) async throws -> Int {
        try await fallbackTokenCounter.tokenCount(for: text)
    }
}

@MainActor
public final class StyleRewriteTextTransformer: DictationTextTransforming {
    public typealias ChunkResponderProvider = @MainActor (TextTransformRequest) -> any TextTransformChunkResponding

    private let tokenCounter: any TextTransformTokenCounting
    private let chunkResponderProvider: ChunkResponderProvider

    public init(
        tokenCounter: any TextTransformTokenCounting = StyleRewriteTextTransformTokenCounter(),
        chunkResponderProvider: @escaping ChunkResponderProvider
    ) {
        self.tokenCounter = tokenCounter
        self.chunkResponderProvider = chunkResponderProvider
    }

    public func prewarm(request: TextTransformRequest) {}

    public func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        let transformStart = Date()

        if request.styleIdentifier == StyleRewriteStyle.chill.styleIdentifier {
            return await transformChill(request, transformStart: transformStart)
        }

        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: tokenCounter),
            responder: chunkResponderProvider(request)
        )
        let result = await runner.transform(request)

        if request.styleIdentifier == StyleRewriteStyle.casual.styleIdentifier {
            return cleanupResult(request: request, result: result)
        }

        let finalText = StyleRewriteOutputRepair.repairDeletedSeparatorPunctuation(
            original: request.baseText,
            rewritten: result.finalText
        )
        let repairedResult = result.withProcessingMode(
            "local-model",
            finalText: finalText,
            applied: finalText != request.baseText && result.errors.isEmpty
        )
        return StyleRewritePromptLeakGuard.fallbackIfNeeded(
            request: request,
            result: repairedResult,
            processingMode: "local-model-prompt-leak-fallback"
        )
    }

    private func transformChill(
        _ request: TextTransformRequest,
        transformStart: Date
    ) async -> TextTransformResult {
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: tokenCounter),
            responder: chunkResponderProvider(request)
        )
        let runnerResult = await runner.transform(request)
        let cleanupSucceeded = runnerResult.errors.isEmpty
        let punctuationRepairedCleanup = cleanupSucceeded
            ? StyleRewriteOutputRepair.repairDeletedSeparatorPunctuation(
                original: request.baseText,
                rewritten: runnerResult.finalText
            )
            : nil
        let sourceText = cleanupSucceeded
            ? punctuationRepairedCleanup ?? runnerResult.finalText
            : request.baseText
        let processingMode: String
        if !cleanupSucceeded {
            processingMode = "local-model-cleanup-failed+heuristic"
        } else {
            processingMode = "local-model-cleanup+heuristic"
        }

        let result = chillResult(
            request: request,
            sourceText: sourceText,
            transformStart: transformStart,
            chunkCount: runnerResult.chunkCount,
            chunkTimings: runnerResult.chunkTimings,
            errors: runnerResult.errors,
            processingMode: processingMode,
            appliedOverride: cleanupSucceeded ? nil : false
        )
        return StyleRewritePromptLeakGuard.fallbackIfNeeded(
            request: request,
            result: result,
            processingMode: "local-model-prompt-leak-fallback"
        )
    }

    private func chillResult(
        request: TextTransformRequest,
        sourceText: String,
        transformStart: Date,
        chunkCount: Int? = nil,
        chunkTimings: [TextTransformChunkTiming] = [],
        errors: [TextTransformErrorSummary] = [],
        processingMode: String,
        appliedOverride: Bool? = nil
    ) -> TextTransformResult {
        let formattedText = ChillHeuristicFormatter().format(sourceText)
        return TextTransformResult(
            originalText: request.baseText,
            finalText: formattedText,
            styleIdentifier: request.styleIdentifier,
            duration: Date().timeIntervalSince(transformStart),
            chunkCount: chunkCount ?? (request.baseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1),
            applied: appliedOverride ?? (formattedText != request.baseText),
            chunkTimings: chunkTimings,
            errors: errors,
            processingMode: processingMode
        )
    }

    private func cleanupResult(
        request: TextTransformRequest,
        result: TextTransformResult
    ) -> TextTransformResult {
        let finalText = StyleRewriteOutputRepair.repairDeletedSeparatorPunctuation(
            original: request.baseText,
            rewritten: result.finalText
        )
        let processingMode = result.errors.isEmpty
            ? "local-model-cleanup"
            : "local-model-cleanup-partial"

        let repairedResult = TextTransformResult(
            originalText: request.baseText,
            finalText: finalText,
            styleIdentifier: request.styleIdentifier,
            duration: result.duration,
            chunkCount: result.chunkCount,
            applied: finalText != request.baseText && result.errors.isEmpty,
            chunkTimings: result.chunkTimings,
            errors: result.errors,
            processingMode: processingMode
        )
        return StyleRewritePromptLeakGuard.fallbackIfNeeded(
            request: request,
            result: repairedResult,
            processingMode: "local-model-prompt-leak-fallback"
        )
    }
}

private extension TextTransformResult {
    func withProcessingMode(
        _ processingMode: String,
        finalText: String? = nil,
        applied: Bool
    ) -> TextTransformResult {
        TextTransformResult(
            originalText: originalText,
            finalText: finalText ?? self.finalText,
            styleIdentifier: styleIdentifier,
            duration: duration,
            chunkCount: chunkCount,
            applied: applied,
            chunkTimings: chunkTimings,
            errors: errors,
            processingMode: processingMode
        )
    }
}
