import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
final class StyleRewritePipelineCoordinator {
    private let selectedStyleProvider: () -> StyleRewriteStyle
    private let artifactStore: StyleRewriteLatestArtifactStore
    private let textTransformer: any DictationTextTransforming

    init(
        selectedStyleProvider: @escaping () -> StyleRewriteStyle,
        artifactStore: StyleRewriteLatestArtifactStore,
        textTransformer: any DictationTextTransforming
    ) {
        self.selectedStyleProvider = selectedStyleProvider
        self.artifactStore = artifactStore
        self.textTransformer = textTransformer
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

    func releasePrewarmSession(reason: String) {}

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

    private func log(_ message: String) {
        #if DEBUG
        NSLog("[StyleRewritePipelineCoordinator] %@", message)
        #endif
    }
}
