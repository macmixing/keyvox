import UIKit

protocol KeyboardTextDocumentProxying: AnyObject {
    var documentContextBeforeInput: String? { get }
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

    init(
        documentProxy: any KeyboardTextDocumentProxying,
        emitKeypress: @escaping () -> Void
    ) {
        self.documentProxy = documentProxy
        self.emitKeypress = emitKeypress
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
            guard canDeleteBackward else { return false }
            emitKeypress()
            documentProxy.deleteBackward()
            return true
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

        let insertionText = KeyboardInsertionSpacingHeuristics.applySmartLeadingSeparatorIfNeeded(
            to: cleanedText,
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

    private var canDeleteBackward: Bool {
        if let selectedText = documentProxy.selectedText, selectedText.isEmpty == false {
            return true
        }

        guard let context = documentProxy.documentContextBeforeInput else {
            return false
        }

        return !context.isEmpty
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
