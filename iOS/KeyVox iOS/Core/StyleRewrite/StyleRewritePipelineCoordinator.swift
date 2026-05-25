import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
final class StyleRewritePipelineCoordinator {
    private let selectedStyleProvider: () -> StyleRewriteStyle
    private let artifactStore: StyleRewriteLatestArtifactStore
    private let textTransformer: any DictationTextTransforming
    private let modelOutputProvider: (String, String) -> String?
    private let releaseResources: @MainActor (String) async -> Void

    init(
        selectedStyleProvider: @escaping () -> StyleRewriteStyle,
        artifactStore: StyleRewriteLatestArtifactStore,
        textTransformer: any DictationTextTransforming,
        modelOutputProvider: @escaping (String, String) -> String? = { _, _ in nil },
        releaseResources: @escaping @MainActor (String) async -> Void = { _ in }
    ) {
        self.selectedStyleProvider = selectedStyleProvider
        self.artifactStore = artifactStore
        self.textTransformer = textTransformer
        self.modelOutputProvider = modelOutputProvider
        self.releaseResources = releaseResources
    }

    func prewarmForUpcomingDictationIfNeeded() {
        let style = selectedStyleProvider()
        guard style.usesModelRewrite else {
            log("prewarm skipped reason=style style=\(style.styleIdentifier)")
            return
        }

        guard let request = transformRequest(for: "") else {
            log("prewarm skipped reason=no-request style=\(style.styleIdentifier)")
            return
        }

        textTransformer.prewarm(request: request)
    }

    func processOutputText(_ baseText: String) async -> DictationPipelineTextProcessingResult {
        guard let request = transformRequest(for: baseText) else {
            return .unchanged(baseText)
        }

        let result = await textTransformer.transform(request)
        recordRewriteTrace(request: request, result: result)
        let errors = result.errors.map(\.message)
        return DictationPipelineTextProcessingResult(
            text: result.finalText,
            duration: result.duration,
            applied: result.applied,
            styleIdentifier: result.styleIdentifier.nilIfEmpty,
            chunkCount: result.chunkCount,
            errorDescription: errors.joined(separator: "; ").nilIfEmpty,
            errors: errors,
            processingMode: result.processingMode
        )
    }

    func releasePrewarmSession(reason: String) async {
        await releaseResources(reason)
    }

    func handleKeyboardStyleRewriteRequest() async {
        guard let request = KeyVoxIPCBridge.consumeStyleRewriteRequest() else {
            return
        }

        guard let style = StyleRewriteStyle(rawValue: request.styleIdentifier) else {
            KeyVoxIPCBridge.writeStyleRewriteResponse(
                KeyVoxStyleRewriteIPCResponse(
                    id: request.id,
                    text: nil,
                    duration: 0,
                    applied: false,
                    chunkCount: 0,
                    errorMessage: "invalidStyle"
                )
            )
            return
        }

        guard let transformRequest = StyleRewriteDictationConfiguration.request(
            for: style,
            baseText: request.baseText
        ) else {
            KeyVoxIPCBridge.writeStyleRewriteResponse(
                KeyVoxStyleRewriteIPCResponse(
                    id: request.id,
                    text: request.baseText,
                    duration: 0,
                    applied: false,
                    chunkCount: request.baseText.isEmpty ? 0 : 1,
                    errorMessage: nil
                )
            )
            return
        }

        let result = await textTransformer.transform(transformRequest)
        recordRewriteTrace(request: transformRequest, result: result)
        log(
            "keyboardResult id=\(request.id.uuidString) style=\(request.styleIdentifier) applied=\(result.applied) mode=\(result.processingMode ?? "nil") final=\(debugText(result.finalText))"
        )
        let errorMessage = result.errors.map(\.message).joined(separator: "; ").nilIfEmpty
        KeyVoxIPCBridge.writeStyleRewriteResponse(
            KeyVoxStyleRewriteIPCResponse(
                id: request.id,
                text: result.finalText,
                duration: result.duration,
                applied: result.applied,
                chunkCount: result.chunkCount,
                errorMessage: errorMessage
            )
        )
    }

    func recordLatestArtifact(from result: DictationPipelineResult, selectedText: String) {
        guard !result.wasLikelyNoSpeech else {
            artifactStore.clear()
            return
        }

        let variants: [DictationTextVariantArtifact]
        if let styleIdentifier = result.textTransformationStyleIdentifier {
            variants = [
                DictationTextVariantArtifact(
                    styleIdentifier: styleIdentifier,
                    text: result.finalText,
                    duration: result.textTransformationDuration,
                    chunkCount: result.textTransformationChunkCount,
                    applied: result.textTransformationApplied,
                    errors: result.textTransformationErrors
                )
            ]
        } else {
            variants = []
        }

        artifactStore.save(
            DictationUtteranceArtifact(
                id: result.id,
                rawText: result.rawText,
                baseText: result.baseText,
                selectedText: selectedText,
                selectedStyleIdentifier: result.textTransformationStyleIdentifier,
                variants: variants,
                deterministicVariants: result.deterministicVariants.map { variant in
                    DictationDeterministicTextVariantArtifact(
                        paragraphsEnabled: variant.paragraphsEnabled,
                        listsEnabled: variant.listsEnabled,
                        text: variant.text
                    )
                },
                inferenceDuration: result.inferenceDuration,
                textTransformationDuration: result.textTransformationDuration,
                createdAt: Date()
            )
        )
    }

    private func transformRequest(for baseText: String) -> TextTransformRequest? {
        StyleRewriteDictationConfiguration.request(
            for: selectedStyleProvider(),
            baseText: baseText
        )
    }

    private func recordRewriteTrace(
        request: TextTransformRequest,
        result: TextTransformResult
    ) {
        var metadata: [String: String] = [
            "applied": result.applied ? "true" : "false",
            "chunk_count": String(result.chunkCount),
            "duration": String(result.duration)
        ]
        if let processingMode = result.processingMode {
            metadata["processing_mode"] = processingMode
        }

        PersonalDictationCaptureStore.shared.recordRewriteTrace(
            styleIdentifier: request.styleIdentifier,
            sourceText: request.baseText,
            modelOutputText: modelOutputProvider(request.styleIdentifier, request.baseText),
            postprocessedOutputText: result.finalText,
            metadata: metadata
        )
    }

    private func log(_ message: String) {
        #if DEBUG
        NSLog("[StyleRewritePipelineCoordinator] %@", message)
        #endif
    }

    private func debugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
