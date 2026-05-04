import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
final class MacVibesCoordinator {
    private let appSettings: AppSettingsStore
    private let textTransformer: FoundationStyleRewriteTextTransformer
    private let isFoundationRewriteAvailable: () -> Bool

    init(
        appSettings: AppSettingsStore,
        isFoundationRewriteAvailable: @escaping () -> Bool = { FoundationStyleRewriteAvailability.isAvailable }
    ) {
        self.appSettings = appSettings
        self.textTransformer = FoundationStyleRewriteTextTransformer()
        self.isFoundationRewriteAvailable = isFoundationRewriteAvailable
    }

    init(
        appSettings: AppSettingsStore,
        textTransformer: FoundationStyleRewriteTextTransformer,
        isFoundationRewriteAvailable: @escaping () -> Bool = { FoundationStyleRewriteAvailability.isAvailable }
    ) {
        self.appSettings = appSettings
        self.textTransformer = textTransformer
        self.isFoundationRewriteAvailable = isFoundationRewriteAvailable
    }

    var selectedVibe: StyleRewriteStyle {
        resolvedStyle(appSettings.selectedVibe)
    }

    var canUseVibes: Bool {
        isFoundationRewriteAvailable()
    }

    @discardableResult
    func advanceSelectedVibe() -> StyleRewriteStyle {
        guard canUseVibes else {
            appSettings.selectedVibe = .none
            return .none
        }

        return appSettings.advanceSelectedVibe()
    }

    func prewarmForUpcomingDictationIfNeeded() {
        let style = selectedVibe
        guard style.usesFoundationRewrite,
              let request = StyleRewriteDictationConfiguration.request(for: style, baseText: "") else {
            log("prewarm skipped reason=style style=\(style.styleIdentifier)")
            return
        }

        textTransformer.prewarm(request: request)
    }

    func processOutputText(_ text: String) async -> DictationPipelineTextProcessingResult {
        let style = selectedVibe
        guard style.usesFoundationRewrite else {
            return .unchanged(text)
        }

        let result = await transform(text, style: style)
        releasePrewarmSession(reason: "mac-dictation-transform")
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
        let resolvedStyle = resolvedStyle(style)
        guard let request = StyleRewriteDictationConfiguration.request(
            for: resolvedStyle,
            baseText: text
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

    func releasePrewarmSession(reason: String) {
        textTransformer.releasePrewarmSession(reason: reason)
    }

    private func resolvedStyle(_ style: StyleRewriteStyle) -> StyleRewriteStyle {
        let resolved = style.resolvedForFoundationAvailability(isFoundationRewriteAvailable())
        if resolved != style {
            appSettings.selectedVibe = resolved
        }
        return resolved
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[MacVibes] \(message())")
        #endif
    }
}
