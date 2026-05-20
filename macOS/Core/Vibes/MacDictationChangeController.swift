import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
final class MacDictationChangeController {
    private struct Session {
        let sourceText: String
        let originalText: String
        var currentText: String
        var currentStyle: StyleRewriteStyle
        var previousStyle: StyleRewriteStyle?
        var variants: [StyleRewriteStyle: String]
    }

    private let pasteService: PasteService
    private let vibesCoordinator: MacVibesCoordinator
    private var activeSession: Session?
    private var isApplyingChange = false

    var currentStyle: StyleRewriteStyle {
        activeSession?.currentStyle ?? .none
    }

    convenience init(vibesCoordinator: MacVibesCoordinator) {
        self.init(pasteService: .shared, vibesCoordinator: vibesCoordinator)
    }

    init(
        pasteService: PasteService,
        vibesCoordinator: MacVibesCoordinator
    ) {
        self.pasteService = pasteService
        self.vibesCoordinator = vibesCoordinator
    }

    func recordInsertedDictation(_ result: DictationPipelineResult) {
        let selectedStyle = result.textTransformationStyleIdentifier.flatMap(StyleRewriteStyle.init(rawValue:)) ?? .none
        var variants: [StyleRewriteStyle: String] = [.none: result.baseText]
        variants[selectedStyle] = result.finalText

        activeSession = Session(
            sourceText: result.baseText,
            originalText: result.baseText,
            currentText: result.finalText,
            currentStyle: selectedStyle,
            previousStyle: nil,
            variants: variants
        )
    }

    func applyLongPressChange(
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> Bool {
        guard vibesCoordinator.canUseVibes, isApplyingChange == false else {
            return false
        }

        isApplyingChange = true
        defer { isApplyingChange = false }

        guard var session = activeSession else {
            log("apply skipped reason=no-session")
            return false
        }

        guard pasteService.currentTextMatchesUntouchedInsertion(session.currentText) else {
            activeSession = nil
            log("apply skipped reason=changed")
            return false
        }

        guard let targetStyle = targetStyle(for: session) else {
            log("apply skipped reason=no-target")
            return false
        }
        log(
            "apply requested currentStyle=\(session.currentStyle.styleIdentifier) " +
            "targetStyle=\(targetStyle.styleIdentifier)" +
            rawTextDebugField("currentText", session.currentText)
        )

        guard let replacementText = await replacementText(
            for: targetStyle,
            session: &session,
            onProcessingStart: onProcessingStart,
            onProcessingEnd: onProcessingEnd
        ) else {
            return false
        }

        guard pasteService.replaceUntouchedInsertion(session.currentText, with: replacementText) else {
            activeSession = nil
            log("apply skipped reason=replace-failed")
            return false
        }

        session.currentText = replacementText
        session.previousStyle = session.currentStyle
        session.currentStyle = targetStyle
        session.variants[targetStyle] = replacementText
        activeSession = session
        log(
            "apply succeeded style=\(targetStyle.styleIdentifier)" +
            rawTextDebugField("finalText", replacementText)
        )
        return true
    }

    private func targetStyle(for session: Session) -> StyleRewriteStyle? {
        let selectedStyle = vibesCoordinator.selectedVibe
        if selectedStyle == session.currentStyle {
            if let previousStyle = session.previousStyle {
                return previousStyle
            }
            return selectedStyle == StyleRewriteStyle.none ? nil : StyleRewriteStyle.none
        }

        return selectedStyle
    }

    private func replacementText(
        for targetStyle: StyleRewriteStyle,
        session: inout Session,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> String? {
        if let cachedText = session.variants[targetStyle] {
            log(
                "replacement cached style=\(targetStyle.styleIdentifier)" +
                rawTextDebugField("finalText", cachedText)
            )
            return cachedText
        }

        guard targetStyle != .none else {
            log(
                "replacement restored style=none" +
                rawTextDebugField("finalText", session.originalText)
            )
            return session.originalText
        }

        onProcessingStart()
        let result = await vibesCoordinator.transform(session.sourceText, style: targetStyle)
        await vibesCoordinator.releasePrewarmSession(reason: "mac-vibe-change")
        onProcessingEnd()
        logTextTransformationResult(result)
        guard result.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            log("apply skipped reason=empty-transform style=\(targetStyle.styleIdentifier)")
            return nil
        }

        session.variants[targetStyle] = result.finalText
        return result.finalText
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[MacVibesChange] \(message())")
        #endif
    }

    private func logTextTransformationResult(_ result: TextTransformResult) {
        #if DEBUG
        let duration = String(format: "%.3f", result.duration)
        let mode = result.processingMode.map { " mode=\($0)" } ?? ""
        let errorSummary = result.errors.isEmpty
            ? ""
            : " errors=\(result.errors.map(\.message).joined(separator: "|"))"
        log(
            "transform duration=\(duration)s applied=\(result.applied) " +
            "style=\(result.styleIdentifier)\(mode) chunks=\(result.chunkCount)" +
            errorSummary +
            rawTextDebugField("original", result.originalText) +
            rawTextDebugField("finalText", result.finalText)
        )
        #endif
    }

    private var rawDebugTextLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"
    }

    private func rawTextDebugField(_ label: String, _ text: String) -> String {
        guard rawDebugTextLoggingEnabled else { return "" }
        return " \(label)=\(escapedDebugText(text))"
    }

    private func escapedDebugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
