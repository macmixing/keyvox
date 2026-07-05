import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
final class MacVibesCoordinator {
    private let appSettings: AppSettingsStore
    private let textTransformer: any DictationTextTransforming
    private let isModelReady: () -> Bool
    private let releaseResources: @MainActor (String) async -> Void

    init(
        appSettings: AppSettingsStore,
        textTransformer: any DictationTextTransforming,
        isModelReady: @escaping () -> Bool,
        releaseResources: @escaping @MainActor (String) async -> Void = { _ in }
    ) {
        self.appSettings = appSettings
        self.textTransformer = textTransformer
        self.isModelReady = isModelReady
        self.releaseResources = releaseResources
    }

    var selectedVibe: StyleRewriteStyle {
        resolvedStyle(appSettings.selectedVibe)
    }

    var canUseVibes: Bool {
        isModelReady()
    }

    @discardableResult
    func advanceSelectedVibe() -> StyleRewriteStyle {
        guard canUseVibes else {
            return .none
        }

        return appSettings.advanceSelectedVibe()
    }

    func prewarmForUpcomingDictationIfNeeded() {
        prewarm(style: selectedVibe)
    }

    func prewarm(style: StyleRewriteStyle) {
        let style = resolvedStyle(style)
        guard style.usesModelRewrite,
              let request = StyleRewriteDictationConfiguration.request(for: style, baseText: "") else {
            log("prewarm skipped reason=style style=\(style.styleIdentifier)")
            return
        }

        textTransformer.prewarm(request: request)
    }

    func processOutputText(_ text: String) async -> DictationPipelineTextProcessingResult {
        let style = selectedVibe
        guard style.usesModelRewrite else {
            return .unchanged(text)
        }

        let result = await transform(text, style: style)
        await releasePrewarmSession(reason: "mac-dictation-transform")
        return DictationPipelineTextProcessingResult(
            text: result.finalText,
            duration: result.duration,
            applied: result.applied,
            styleIdentifier: result.styleIdentifier,
            chunkCount: result.chunkCount,
            errorDescription: result.errors.first?.message,
            errors: result.errors.map(\.message),
            processingMode: result.processingMode
        )
    }

    func processOutputText(_ context: DictationPipelineTextProcessingContext) async -> DictationPipelineTextProcessingResult {
        let style = selectedVibe
        guard style.usesModelRewrite else {
            return .unchanged(context.baseText)
        }

        let result = await transform(
            context.baseText,
            style: style,
            deterministicVariants: styleRewriteVariants(from: context.deterministicVariants)
        )
        await releasePrewarmSession(reason: "mac-dictation-transform")
        return DictationPipelineTextProcessingResult(
            text: result.finalText,
            duration: result.duration,
            applied: result.applied,
            styleIdentifier: result.styleIdentifier,
            chunkCount: result.chunkCount,
            errorDescription: result.errors.first?.message,
            errors: result.errors.map(\.message),
            processingMode: result.processingMode
        )
    }

    func transform(_ text: String, style: StyleRewriteStyle) async -> TextTransformResult {
        await transform(text, style: style, deterministicVariants: [])
    }

    private func transform(
        _ text: String,
        style: StyleRewriteStyle,
        deterministicVariants: [StyleRewriteInputVariant]
    ) async -> TextTransformResult {
        let resolvedStyle = resolvedStyle(style)
        guard let request = StyleRewriteDictationConfiguration.request(
            for: resolvedStyle,
            baseText: text,
            deterministicVariants: deterministicVariants
        ) else {
            return TextTransformResult(
                originalText: text,
                finalText: text,
                styleIdentifier: StyleRewriteStyle.none.styleIdentifier,
                duration: 0,
                chunkCount: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1,
                applied: false,
                chunkTimings: [],
                errors: []
            )
        }

        return await textTransformer.transform(request)
    }

    func releasePrewarmSession(reason: String) async {
        await releaseResources(reason)
    }

    private func resolvedStyle(_ style: StyleRewriteStyle) -> StyleRewriteStyle {
        style.resolvedForModelAvailability(isModelReady())
    }

    private func styleRewriteVariants(
        from variants: [DictationPipelineResult.DeterministicTextVariant]
    ) -> [StyleRewriteInputVariant] {
        variants.map { variant in
            StyleRewriteInputVariant(
                paragraphsEnabled: variant.paragraphsEnabled,
                listsEnabled: variant.listsEnabled,
                text: variant.text
            )
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[MacVibes] \(message())")
        #endif
    }
}
