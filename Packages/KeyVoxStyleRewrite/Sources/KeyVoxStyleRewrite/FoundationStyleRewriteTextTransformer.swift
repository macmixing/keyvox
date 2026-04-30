import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct FoundationTextTransformTokenCounter: TextTransformTokenCounting {
    private let fallbackTokenCounter: any TextTransformTokenCounting

    public init(fallbackTokenCounter: any TextTransformTokenCounting = ApproximateTextTransformTokenCounter()) {
        self.fallbackTokenCounter = fallbackTokenCounter
    }

    public func tokenCount(for text: String) async throws -> Int {
        #if canImport(FoundationModels)
        if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
            return try await SystemLanguageModel.default.tokenCount(for: text)
        }
        #endif

        return try await fallbackTokenCounter.tokenCount(for: text)
    }
}

public enum FoundationStyleRewriteError: Error, Equatable, Sendable, CustomStringConvertible {
    case foundationModelsUnavailable
    case refusal
    case guardrailViolation
    case exceededContextWindow
    case generationFailed(String)

    public var description: String {
        switch self {
        case .foundationModelsUnavailable:
            return "foundationModelsUnavailable"
        case .refusal:
            return "foundationRefusal"
        case .guardrailViolation:
            return "foundationGuardrailViolation"
        case .exceededContextWindow:
            return "foundationExceededContextWindow"
        case .generationFailed(let message):
            return "foundationGenerationFailed(\(message))"
        }
    }

    var errorCode: TextTransformErrorCode {
        switch self {
        case .foundationModelsUnavailable:
            return .foundationModelsUnavailable
        case .refusal:
            return .foundationRefusal
        case .guardrailViolation:
            return .foundationGuardrailViolation
        case .exceededContextWindow:
            return .foundationExceededContextWindow
        case .generationFailed:
            return .foundationGenerationFailed
        }
    }
}

public enum FoundationStyleRewriteAvailability {
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return modelIfAvailable() != nil
        }
        #endif

        return false
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    static func modelIfAvailable() -> SystemLanguageModel? {
        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )

        guard case .available = model.availability else {
            return nil
        }

        return model
    }
    #endif
}

@MainActor
public final class FoundationStyleRewriteTextTransformer: DictationTextTransforming {
    private let tokenCounter: any TextTransformTokenCounting

    private var prewarmSessionStore: Any?
    private var prewarmLifecycle = FoundationStyleRewritePrewarmLifecycle()

    public init(tokenCounter: any TextTransformTokenCounting = FoundationTextTransformTokenCounter()) {
        self.tokenCounter = tokenCounter
    }

    public func prewarm(request: TextTransformRequest) {
        guard prewarmLifecycle.shouldRequestPrewarm(for: request.prewarmKey) else {
            log("prewarm skipped reason=already-warm style=\(request.styleIdentifier)")
            return
        }

        let start = Date()
        log("prewarm requested style=\(request.styleIdentifier)")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            guard let session = prewarmSessionIfAvailable(for: request) else {
                prewarmLifecycle.markUnavailable()
                log("prewarm skipped reason=foundation-unavailable style=\(request.styleIdentifier)")
                return
            }

            session.prewarm(promptPrefix: Prompt(request.promptPrefix))
            prewarmLifecycle.markWarm()
            log("prewarm completed style=\(request.styleIdentifier) duration=\(Self.formatDuration(Date().timeIntervalSince(start)))")
            return
        }
        #endif

        prewarmLifecycle.markUnavailable()
        log("prewarm skipped reason=foundation-unavailable style=\(request.styleIdentifier)")
    }

    public func releasePrewarmSession(reason: String = "released") {
        let hadSession = prewarmSessionStore != nil
        let released = prewarmLifecycle.release()
        prewarmSessionStore = nil
        guard hadSession || released else { return }
        log("prewarm session released reason=\(reason) hadSession=\(hadSession)")
    }

    public func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        let transformStart = Date()
        let prewarmUsage = prewarmLifecycle.usage(for: request.prewarmKey)
        log("transform session=\(prewarmUsage.rawValue) style=\(request.styleIdentifier)")

        if request.styleIdentifier == StyleRewriteStyle.chill.styleIdentifier {
            let result = await transformChill(
                request,
                transformStart: transformStart,
                prewarmUsage: prewarmUsage
            )
            return result.withProcessingModeSuffix(prewarmUsage.processingModeSuffix)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            guard let model = modelIfAvailable() else {
                return TextTransformResult.fallback(
                    request: request,
                    duration: Date().timeIntervalSince(transformStart),
                    errors: [TextTransformErrorSummary(
                        chunkIndex: nil,
                        message: FoundationStyleRewriteError.foundationModelsUnavailable.description,
                        errorCode: FoundationStyleRewriteError.foundationModelsUnavailable.errorCode
                    )]
                ).withProcessingModeSuffix(prewarmUsage.processingModeSuffix)
            }

            let runner = TextTransformChunkRunner(
                planner: TextTransformChunkPlanner(tokenCounter: tokenCounter),
                responder: FoundationStyleRewriteChunkResponder(
                    prewarmedSessionProvider: { [weak self] in
                        self?.matchingPrewarmSession(for: request)
                    },
                    fallbackSessionProvider: {
                        LanguageModelSession(model: model, instructions: request.instructions)
                    }
                )
            )
            let result = (await runner.transform(request))
                .withProcessingModeSuffix(prewarmUsage.processingModeSuffix)

            if result.errors.contains(where: Self.requiresFullFallback) {
                return TextTransformResult.fallback(
                    request: request,
                    duration: result.duration,
                    errors: result.errors
                ).withProcessingModeSuffix(prewarmUsage.processingModeSuffix)
            }

            if request.styleIdentifier == StyleRewriteStyle.casual.styleIdentifier {
                return cleanupResult(request: request, result: result)
            }

            return result
        }
        #endif

        return TextTransformResult.fallback(
            request: request,
            duration: Date().timeIntervalSince(transformStart),
            errors: [TextTransformErrorSummary(
                chunkIndex: nil,
                message: FoundationStyleRewriteError.foundationModelsUnavailable.description,
                errorCode: FoundationStyleRewriteError.foundationModelsUnavailable.errorCode
            )]
        ).withProcessingModeSuffix(prewarmUsage.processingModeSuffix)
    }

    private static func requiresFullFallback(_ error: TextTransformErrorSummary) -> Bool {
        switch error.errorCode {
        case .foundationRefusal, .foundationGuardrailViolation:
            return true
        default:
            return false
        }
    }

    private func chillResult(
        request: TextTransformRequest,
        sourceText: String,
        transformStart: Date,
        chunkCount: Int? = nil,
        chunkTimings: [TextTransformChunkTiming] = [],
        processingMode: String = "heuristic"
    ) -> TextTransformResult {
        let formattedText = ChillHeuristicFormatter().format(sourceText)
        return TextTransformResult(
            originalText: request.baseText,
            finalText: formattedText,
            styleIdentifier: request.styleIdentifier,
            duration: Date().timeIntervalSince(transformStart),
            chunkCount: chunkCount ?? (request.baseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1),
            applied: formattedText != request.baseText,
            chunkTimings: chunkTimings,
            errors: [],
            processingMode: processingMode
        )
    }

    private func cleanupResult(
        request: TextTransformRequest,
        result: TextTransformResult
    ) -> TextTransformResult {
        let repaired = FoundationRewriteOutputRepair.repair(
            original: request.baseText,
            rewritten: result.finalText
        )
        let finalText = repaired.text
        let sessionSuffix = result.processingMode.map { "+\($0)" } ?? ""
        let processingMode: String
        if repaired.rejectedProtectedRemoval {
            processingMode = "foundation-cleanup-repaired\(sessionSuffix)"
        } else if result.errors.isEmpty {
            processingMode = "foundation-cleanup\(sessionSuffix)"
        } else {
            processingMode = "foundation-cleanup-partial\(sessionSuffix)"
        }

        return TextTransformResult(
            originalText: request.baseText,
            finalText: finalText,
            styleIdentifier: request.styleIdentifier,
            duration: result.duration,
            chunkCount: result.chunkCount,
            applied: finalText != request.baseText,
            chunkTimings: result.chunkTimings,
            errors: result.errors,
            processingMode: processingMode
        )
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private extension FoundationStyleRewriteTextTransformer {
    func transformChillWithFoundation(
        _ request: TextTransformRequest,
        transformStart: Date,
        prewarmUsage: FoundationStyleRewritePrewarmUsage
    ) async -> TextTransformResult {
        guard let model = modelIfAvailable() else {
            return chillResult(request: request, sourceText: request.baseText, transformStart: transformStart)
        }

        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: tokenCounter),
            responder: FoundationStyleRewriteChunkResponder(
                prewarmedSessionProvider: { [weak self] in
                    self?.matchingPrewarmSession(for: request)
                },
                fallbackSessionProvider: {
                    LanguageModelSession(model: model, instructions: request.instructions)
                }
            )
        )
        let runnerResult = await runner.transform(request)
        let requiresFullFallback = runnerResult.errors.contains(where: Self.requiresFullFallback)
        let repairedCleanup = requiresFullFallback
            ? nil
            : FoundationRewriteOutputRepair.repair(original: request.baseText, rewritten: runnerResult.finalText)
        let sourceText = requiresFullFallback
            ? request.baseText
            : repairedCleanup?.text ?? runnerResult.finalText
        let processingMode: String
        if requiresFullFallback {
            processingMode = "foundation-cleanup-fallback+heuristic"
        } else if repairedCleanup?.rejectedProtectedRemoval == true {
            processingMode = "foundation-cleanup-repaired+heuristic"
        } else if runnerResult.errors.isEmpty {
            processingMode = "foundation-cleanup+heuristic"
        } else {
            processingMode = "foundation-cleanup-partial+heuristic"
        }

        return chillResult(
            request: request,
            sourceText: sourceText,
            transformStart: transformStart,
            chunkCount: runnerResult.chunkCount,
            chunkTimings: runnerResult.chunkTimings,
            processingMode: processingMode
        )
    }

    func modelIfAvailable() -> SystemLanguageModel? {
        FoundationStyleRewriteAvailability.modelIfAvailable()
    }

    func prewarmSessionIfAvailable(for request: TextTransformRequest) -> LanguageModelSession? {
        guard let model = modelIfAvailable() else {
            return nil
        }

        let key = FoundationStyleRewriteSessionKey(
            styleIdentifier: request.styleIdentifier,
            instructions: request.instructions
        )

        let currentStore = prewarmSessionStore as? FoundationStyleRewriteSessionStore
        if currentStore?.key != key {
            prewarmSessionStore = FoundationStyleRewriteSessionStore(
                key: key,
                session: LanguageModelSession(model: model, instructions: request.instructions)
            )
        }

        return (prewarmSessionStore as? FoundationStyleRewriteSessionStore)?.session
    }

    func matchingPrewarmSession(for request: TextTransformRequest) -> LanguageModelSession? {
        guard prewarmLifecycle.usage(for: request.prewarmKey) == .warm else {
            return nil
        }

        return (prewarmSessionStore as? FoundationStyleRewriteSessionStore)?.session
    }
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private struct FoundationStyleRewriteSessionKey: Equatable {
    let styleIdentifier: String
    let instructions: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private struct FoundationStyleRewriteSessionStore {
    let key: FoundationStyleRewriteSessionKey
    let session: LanguageModelSession
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@MainActor
private final class FoundationStyleRewriteChunkResponder: TextTransformChunkResponding {
    private let prewarmedSessionProvider: @MainActor () -> LanguageModelSession?
    private let fallbackSessionProvider: @MainActor () -> LanguageModelSession
    private var usedPrewarmedSession = false

    init(
        prewarmedSessionProvider: @escaping @MainActor () -> LanguageModelSession?,
        fallbackSessionProvider: @escaping @MainActor () -> LanguageModelSession
    ) {
        self.prewarmedSessionProvider = prewarmedSessionProvider
        self.fallbackSessionProvider = fallbackSessionProvider
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        do {
            let session = session(for: chunk)

            let response = try await session.respond(
                to: request.prompt(for: chunk.text),
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0,
                    maximumResponseTokens: maximumResponseTokens(for: request, chunk: chunk)
                )
            )

            if FoundationStyleRewriteOutputPolicy.isRefusalOrMetaResponse(response.content) {
                throw FoundationStyleRewriteError.refusal
            }

            return response.content
        } catch LanguageModelSession.GenerationError.refusal {
            throw FoundationStyleRewriteError.refusal
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            throw FoundationStyleRewriteError.guardrailViolation
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            throw FoundationStyleRewriteError.exceededContextWindow
        } catch {
            throw FoundationStyleRewriteError.generationFailed(String(describing: error))
        }
    }

    private func session(for chunk: TextTransformChunk) -> LanguageModelSession {
        if chunk.index == 0, !usedPrewarmedSession, let session = prewarmedSessionProvider() {
            usedPrewarmedSession = true
            return session
        }

        return fallbackSessionProvider()
    }

    private func maximumResponseTokens(
        for request: TextTransformRequest,
        chunk: TextTransformChunk
    ) -> Int? {
        guard let requestLimit = request.maximumResponseTokens else {
            return nil
        }

        let estimatedChunkLimit = Int(
            ceil(Double(chunk.inputTokenCount) * max(request.expectedOutputExpansionRatio, 1.0))
        ) + 16 // Buffer for prompt wrapper, formatting overhead, and tokenizer variance.
        return max(1, min(requestLimit, estimatedChunkLimit))
    }
}
#endif

private extension FoundationStyleRewriteTextTransformer {
    func transformChill(
        _ request: TextTransformRequest,
        transformStart: Date,
        prewarmUsage: FoundationStyleRewritePrewarmUsage
    ) async -> TextTransformResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return await transformChillWithFoundation(
                request,
                transformStart: transformStart,
                prewarmUsage: prewarmUsage
            )
        }
        #endif

        return chillResult(request: request, sourceText: request.baseText, transformStart: transformStart)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.3f", duration)
    }

    func log(_ message: String) {
        #if DEBUG
        NSLog("[StyleRewriteFoundation] %@", message)
        #endif
    }
}

struct FoundationStyleRewritePrewarmKey: Equatable, Sendable {
    let styleIdentifier: String
    let instructions: String
    let promptPrefix: String
}

enum FoundationStyleRewritePrewarmUsage: String, Equatable, Sendable {
    case cold
    case warm

    var processingModeSuffix: String {
        switch self {
        case .cold:
            return "cold"
        case .warm:
            return "warm"
        }
    }
}

struct FoundationStyleRewritePrewarmLifecycle: Equatable, Sendable {
    private(set) var activeKey: FoundationStyleRewritePrewarmKey?
    private(set) var isWarm = false

    mutating func shouldRequestPrewarm(for key: FoundationStyleRewritePrewarmKey) -> Bool {
        guard activeKey != key || !isWarm else {
            return false
        }

        activeKey = key
        isWarm = false
        return true
    }

    mutating func markWarm() {
        isWarm = activeKey != nil
    }

    mutating func markUnavailable() {
        activeKey = nil
        isWarm = false
    }

    func usage(for key: FoundationStyleRewritePrewarmKey) -> FoundationStyleRewritePrewarmUsage {
        activeKey == key && isWarm ? .warm : .cold
    }

    mutating func release() -> Bool {
        let hadSession = activeKey != nil || isWarm
        activeKey = nil
        isWarm = false
        return hadSession
    }
}

private extension TextTransformRequest {
    var prewarmKey: FoundationStyleRewritePrewarmKey {
        FoundationStyleRewritePrewarmKey(
            styleIdentifier: styleIdentifier,
            instructions: instructions,
            promptPrefix: promptPrefix
        )
    }
}

private extension TextTransformResult {
    func withProcessingModeSuffix(_ suffix: String) -> TextTransformResult {
        let nextMode = processingMode.map { "\($0)+\(suffix)" } ?? suffix
        return TextTransformResult(
            originalText: originalText,
            finalText: finalText,
            styleIdentifier: styleIdentifier,
            duration: duration,
            chunkCount: chunkCount,
            applied: applied,
            chunkTimings: chunkTimings,
            errors: errors,
            processingMode: nextMode
        )
    }
}

enum FoundationStyleRewriteOutputPolicy {
    static func isRefusalOrMetaResponse(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return false }

        let refusalLeadIns = [
            "i cannot",
            "i can't",
            "i am unable",
            "i'm unable",
            "i’m unable",
            "i am sorry",
            "i'm sorry",
            "i’m sorry",
            "sorry,"
        ]
        guard refusalLeadIns.contains(where: { normalized.hasPrefix($0) }) else {
            return false
        }

        let taskTerms = [
            "format",
            "rewrite",
            "transform",
            "edit",
            "provided",
            "request",
            "text",
            "content",
            "offensive",
            "inappropriate"
        ]
        return taskTerms.contains(where: normalized.contains)
    }
}
