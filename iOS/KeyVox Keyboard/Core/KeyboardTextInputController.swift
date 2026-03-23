import UIKit

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
        proxyProvider()?.insertText(text)
    }

    func deleteBackward() {
        proxyProvider()?.deleteBackward()
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        proxyProvider()?.adjustTextPosition(byCharacterOffset: offset)
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
        advanceToNextInputMode: () -> Void
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
                return true
            }
            documentProxy.insertText(" ")
            return true
        case .returnKey:
            emitKeypress()
            documentProxy.insertText("\n")
            return true
        case .abc:
            emitKeypress()
            resetCapsLockStateIfNeeded()
            advanceToNextInputMode()
            return true
        case .alternateSymbols, .numberSymbols:
            emitKeypress()
            symbolPage.toggle()
            return true
        }
    }

    @discardableResult
    func insertTranscription(_ text: String) -> Bool {
        let cleanedText = text.replacingOccurrences(
            of: #"[\r\n]+$"#,
            with: "",
            options: .regularExpression
        )
        guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let capitalizationNormalizedText = KeyboardInsertionCapitalizationHeuristics
            .normalizeLeadingCapitalizationIfNeeded(
                text: cleanedText,
                documentContextBeforeInput: documentProxy.documentContextBeforeInput,
                shouldPreserveLeadingCapitalization: shouldPreserveLeadingCapitalization
            )
        let insertionText = KeyboardInsertionSpacingHeuristics.applySmartLeadingSeparatorIfNeeded(
            to: capitalizationNormalizedText,
            documentContextBeforeInput: documentProxy.documentContextBeforeInput
        )
        documentProxy.insertText(insertionText)
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
