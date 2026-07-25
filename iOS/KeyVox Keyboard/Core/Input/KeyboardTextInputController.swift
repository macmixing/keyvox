import UIKit

struct KeyboardTextInsertionResult: Equatable {
    let sourceText: String
    let insertedText: String
    let documentContextBeforeInput: String?
}

protocol KeyboardTextDocumentProxying: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var hasText: Bool { get }
    var selectedText: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
    func adjustTextPosition(byCharacterOffset offset: Int)
}

final class KeyboardTextDocumentProxyAdapter: KeyboardTextDocumentProxying {
    private let proxyProvider: () -> UITextDocumentProxy?

    init(proxyProvider: @escaping () -> UITextDocumentProxy?) {
        self.proxyProvider = proxyProvider
    }

    var documentContextBeforeInput: String? {
        proxyProvider()?.documentContextBeforeInput
    }

    var documentContextAfterInput: String? {
        proxyProvider()?.documentContextAfterInput
    }

    var hasText: Bool {
        proxyProvider()?.hasText ?? false
    }

    var selectedText: String? {
        proxyProvider()?.selectedText
    }

    func insertText(_ text: String) {
        let proxy = proxyProvider()
        let startedAt = ProcessInfo.processInfo.systemUptime
        KeyboardTypingDiagnostics.log("proxy_insert_begin", fields: [
            "text": text,
            "text_count": text.count,
            "context_count_before": proxy?.documentContextBeforeInput?.count ?? -1,
            "proxy_available": proxy != nil,
        ])
        proxy?.insertText(text)
        KeyboardTypingDiagnostics.log("proxy_insert_end", fields: [
            "text": text,
            "context_count_after": proxy?.documentContextBeforeInput?.count ?? -1,
            "duration_ms": diagnosticMilliseconds(since: startedAt),
        ])
    }

    func deleteBackward() {
        let proxy = proxyProvider()
        let startedAt = ProcessInfo.processInfo.systemUptime
        KeyboardTypingDiagnostics.log("proxy_delete_begin", fields: [
            "context_count_before": proxy?.documentContextBeforeInput?.count ?? -1,
            "proxy_available": proxy != nil,
        ])
        proxy?.deleteBackward()
        KeyboardTypingDiagnostics.log("proxy_delete_end", fields: [
            "context_count_after": proxy?.documentContextBeforeInput?.count ?? -1,
            "duration_ms": diagnosticMilliseconds(since: startedAt),
        ])
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        proxyProvider()?.adjustTextPosition(byCharacterOffset: offset)
    }

    private func diagnosticMilliseconds(since start: TimeInterval) -> Double {
        ((ProcessInfo.processInfo.systemUptime - start) * 100_000).rounded() / 100
    }
}

final class KeyboardTextInputController {
    private let documentProxy: any KeyboardTextDocumentProxying
    private let emitKeypress: () -> Void
    private let shouldPreserveLeadingCapitalization: (String) -> Bool

    private var emptyContextDeleteAttempts = 0
    private var lastDeleteTimestamp: TimeInterval = 0

    init(
        documentProxy: any KeyboardTextDocumentProxying,
        emitKeypress: @escaping () -> Void,
        shouldPreserveLeadingCapitalization: @escaping (String) -> Bool = { _ in false }
    ) {
        self.documentProxy = documentProxy
        self.emitKeypress = emitKeypress
        self.shouldPreserveLeadingCapitalization = shouldPreserveLeadingCapitalization
    }

    @discardableResult
    func handleKeyActivation(
        _ kind: KeyboardKeyKind,
        symbolPage: inout KeyboardSymbolPage,
        resetCapsLockStateIfNeeded: () -> Void,
        advanceToNextInputMode: () -> Void,
        handleShift: () -> Void = {}
    ) -> Bool {
        switch kind {
        case let .character(value):
            emitKeypress()
            documentProxy.insertText(value)
            return true
        case .delete:
            let now = Date().timeIntervalSince1970
            let isNewDeleteSession = now - lastDeleteTimestamp > 0.5
            if isNewDeleteSession {
                emptyContextDeleteAttempts = 0
            }
            lastDeleteTimestamp = now
            
            let proxySeemsEmpty = (documentProxy.documentContextBeforeInput?.isEmpty ?? true) &&
                                  (documentProxy.selectedText?.isEmpty ?? true) &&
                                  !documentProxy.hasText

            if !proxySeemsEmpty {
                emptyContextDeleteAttempts = 0
                emitKeypress()
                documentProxy.deleteBackward()
                return true
            } else {
                if emptyContextDeleteAttempts < 3 {
                    if emptyContextDeleteAttempts == 0 && isNewDeleteSession {
                        emitKeypress()
                    }
                    emptyContextDeleteAttempts += 1
                    documentProxy.deleteBackward()
                    return true
                } else {
                    return false
                }
            }
        case .space:
            emitKeypress()
            if handleDoubleSpacePeriodInsertionIfNeeded() {
                symbolPage = .alphabetic
                return true
            }
            documentProxy.insertText(" ")
            symbolPage = .alphabetic
            return true
        case .returnKey:
            emitKeypress()
            documentProxy.insertText("\n")
            return true
        case .abc:
            emitKeypress()
            symbolPage = .alphabetic
            return true
        case .shift:
            emitKeypress()
            handleShift()
            return true
        case .nextKeyboard:
            emitKeypress()
            resetCapsLockStateIfNeeded()
            advanceToNextInputMode()
            return true
        case .alternateSymbols:
            emitKeypress()
            symbolPage = .alternate
            return true
        case .numberSymbols:
            emitKeypress()
            symbolPage = .primary
            return true
        }
    }

    @discardableResult
    func insertTranscription(_ text: String) -> Bool {
        insertTranscriptionWithResult(text) != nil
    }

    func insertTranscriptionWithResult(_ text: String) -> KeyboardTextInsertionResult? {
        let cleanedText = text.replacingOccurrences(
            of: #"[\r\n]+$"#,
            with: "",
            options: .regularExpression
        )
        guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let contextBeforeInput = documentProxy.documentContextBeforeInput
        let insertionText = preparedTranscriptionText(
            cleanedText,
            documentContextBeforeInput: contextBeforeInput
        )
        documentProxy.insertText(insertionText)
        return KeyboardTextInsertionResult(
            sourceText: cleanedText,
            insertedText: insertionText,
            documentContextBeforeInput: contextBeforeInput
        )
    }

    func preparedTranscriptionText(
        _ text: String,
        documentContextBeforeInput: String?
    ) -> String {
        let capitalizationNormalizedText = KeyboardInsertionCapitalizationCoordinator
            .normalizeLeadingCapitalizationIfNeeded(
                text: text,
                documentContextBeforeInput: documentContextBeforeInput,
                shouldPreserveLeadingCapitalization: shouldPreserveLeadingCapitalization
            )
        #if DEBUG
        logNormalizationStage(
            "capitalizationNormalized",
            input: text,
            output: capitalizationNormalizedText
        )
        #endif
        let insertionText = KeyboardInsertionSpacingCoordinator.applySmartLeadingSeparatorIfNeeded(
            to: capitalizationNormalizedText,
            documentContextBeforeInput: documentContextBeforeInput
        )
        #if DEBUG
        logNormalizationStage(
            "spacingNormalized",
            input: capitalizationNormalizedText,
            output: insertionText
        )
        #endif
        return insertionText
    }

    #if DEBUG
    private func logNormalizationStage(_ stage: String, input: String, output: String) {
        print(
            "[KVXKeyboardInsert] \(stage) changed=\(input != output) "
                + "inputLength=\(input.count) outputLength=\(output.count)"
        )
    }
    #endif

    var selectedText: String? {
        documentProxy.selectedText
    }

    var documentContextBeforeInput: String? {
        documentProxy.documentContextBeforeInput
    }

    func currentTextMatchesUntouchedInsertion(
        _ text: String,
        documentContextBeforeInsertion: String?
    ) -> Bool {
        guard text.isEmpty == false else {
            return false
        }

        guard let currentContext = documentProxy.documentContextBeforeInput else {
            return false
        }

        guard currentContext.hasSuffix(text) else {
            return false
        }

        let visiblePrefix = String(currentContext.dropLast(text.count))
        guard visiblePrefix.isEmpty == false else {
            return documentContextBeforeInsertion?.isEmpty ?? true
        }

        guard let documentContextBeforeInsertion else {
            return false
        }

        return documentContextBeforeInsertion.hasSuffix(visiblePrefix)
    }

    @discardableResult
    func replaceCurrentWord(
        _ currentWord: String,
        with replacement: String,
        appendingSpace: Bool
    ) -> Bool {
        guard currentWord.isEmpty == false,
              replacement.isEmpty == false,
              documentProxy.documentContextBeforeInput?.hasSuffix(currentWord) == true else {
            return false
        }
        for _ in currentWord {
            documentProxy.deleteBackward()
        }
        documentProxy.insertText(replacement + (appendingSpace ? " " : ""))
        return true
    }

    @discardableResult
    func restoreAutomaticCorrection(
        original: String,
        replacement: String
    ) -> Bool {
        let correctedText = replacement + " "
        guard documentProxy.documentContextBeforeInput?.hasSuffix(correctedText) == true else {
            return false
        }
        for _ in correctedText {
            documentProxy.deleteBackward()
        }
        documentProxy.insertText(original)
        return true
    }

    @discardableResult
    func insertPrediction(
        _ prediction: String,
        replacing currentWord: String
    ) -> Bool {
        guard prediction.isEmpty == false else { return false }
        if currentWord.isEmpty {
            emitKeypress()
            documentProxy.insertText(prediction + " ")
            return true
        }
        emitKeypress()
        return replaceCurrentWord(
            currentWord,
            with: prediction,
            appendingSpace: true
        )
    }

    func replaceSelectedText(_ selectedText: String, with text: String) -> Bool {
        guard selectedText.isEmpty == false,
              let currentSelectedText = documentProxy.selectedText,
              currentSelectedText == selectedText else {
            return false
        }

        documentProxy.insertText(text)
        return true
    }

    func replaceUntouchedInsertion(
        _ currentText: String,
        with replacementText: String,
        documentContextBeforeInsertion: String?
    ) -> Bool {
        guard currentTextMatchesUntouchedInsertion(
            currentText,
            documentContextBeforeInsertion: documentContextBeforeInsertion
        ) else {
            return false
        }

        for _ in currentText {
            documentProxy.deleteBackward()
        }
        documentProxy.insertText(replacementText)
        return true
    }

    func adjustCursorPosition(by offset: Int) {
        guard offset != 0 else { return }

        let step = offset > 0 ? 1 : -1
        for _ in 0..<abs(offset) {
            documentProxy.adjustTextPosition(byCharacterOffset: step)
        }
    }


    private func handleDoubleSpacePeriodInsertionIfNeeded() -> Bool {
        guard let context = documentProxy.documentContextBeforeInput else {
            return false
        }

        guard shouldInsertPeriodAfterDoubleSpace(context: context) else {
            return false
        }

        documentProxy.deleteBackward()
        documentProxy.insertText(". ")
        return true
    }

    private func shouldInsertPeriodAfterDoubleSpace(context: String) -> Bool {
        guard context.last == " " else {
            return false
        }

        let contentBeforeTrailingSpace = context.dropLast()
        guard let previousCharacter = contentBeforeTrailingSpace.last else {
            return false
        }

        let whitespaceAndNewlines = CharacterSet.whitespacesAndNewlines
        let punctuation = CharacterSet.punctuationCharacters

        guard let scalar = previousCharacter.unicodeScalars.first else {
            return false
        }

        if whitespaceAndNewlines.contains(scalar) || punctuation.contains(scalar) {
            return false
        }

        return true
    }
}
