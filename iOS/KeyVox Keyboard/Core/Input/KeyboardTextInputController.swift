import UIKit
import KeyVoxTextComposition

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
    private struct PendingSelectionDeletion {
        let documentContextBeforeInput: String
    }

    private let documentProxy: any KeyboardTextDocumentProxying
    private let emitKeypress: () -> Void
    private let shouldPreserveLeadingCapitalization: (String) -> Bool

    private var emptyContextDeleteAttempts = 0
    private var lastDeleteTimestamp: TimeInterval = 0
    private var pendingSelectionDeletion: PendingSelectionDeletion?

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
            pendingSelectionDeletion = nil
            emitKeypress()
            documentProxy.insertText(value)
            return true
        case .delete:
            let selectedTextBeforeDeletion = documentProxy.selectedText
            let contextBeforeDeletion = documentProxy.documentContextBeforeInput
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
                pendingSelectionDeletion = makePendingSelectionDeletion(
                    selectedText: selectedTextBeforeDeletion,
                    documentContextBeforeInput: contextBeforeDeletion
                )
                emitKeypress()
                documentProxy.deleteBackward()
                return true
            } else {
                pendingSelectionDeletion = nil
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
            pendingSelectionDeletion = nil
            emitKeypress()
            if handleDoubleSpacePeriodInsertionIfNeeded() {
                return true
            }
            documentProxy.insertText(" ")
            return true
        case .returnKey:
            pendingSelectionDeletion = nil
            emitKeypress()
            documentProxy.insertText("\n")
            return true
        case .abc:
            pendingSelectionDeletion = nil
            emitKeypress()
            resetCapsLockStateIfNeeded()
            advanceToNextInputMode()
            return true
        case .alternateSymbols, .numberSymbols:
            emitKeypress()
            symbolPage.toggle()
            return true
        case .restoreFullKeyboard:
            return false
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
        let compositionContextBeforeInput = contextAfterCorrectingPendingSelectionDeletion(
            contextBeforeInput
        )
        let contextAfterInput = documentProxy.documentContextAfterInput
        let followingCharacter = contextAfterInput?.first
        let followingNonWhitespaceCharacter = contextAfterInput?.first(where: {
            $0.isWhitespace == false
        })
        pendingSelectionDeletion = nil
        let preparedText = preparedTranscriptionText(
            cleanedText,
            documentContextBeforeInput: compositionContextBeforeInput
        )
        let punctuationResolution = TerminalPunctuationCompositionPolicy.resolve(
            text: preparedText,
            followingCharacter: followingCharacter,
            followingNonWhitespaceCharacter: followingNonWhitespaceCharacter,
            followingText: contextAfterInput
        )
        let insertionText = TrailingSeparatorCompositionPolicy.applyIfNeeded(
            to: punctuationResolution.text,
            followingCharacter: followingCharacter
        )
        documentProxy.insertText(insertionText)
        if punctuationResolution.shouldReplaceFollowingPunctuation {
            documentProxy.adjustTextPosition(byCharacterOffset: 1)
            documentProxy.deleteBackward()
        }
        return KeyboardTextInsertionResult(
            sourceText: cleanedText,
            insertedText: insertionText,
            documentContextBeforeInput: compositionContextBeforeInput
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

    func replaceSelectedText(_ selectedText: String, with text: String) -> Bool {
        guard selectedText.isEmpty == false,
              let currentSelectedText = documentProxy.selectedText,
              currentSelectedText == selectedText else {
            return false
        }

        pendingSelectionDeletion = nil
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

        pendingSelectionDeletion = nil
        for _ in currentText {
            documentProxy.deleteBackward()
        }
        documentProxy.insertText(replacementText)
        return true
    }

    func adjustCursorPosition(by offset: Int) {
        guard offset != 0 else { return }

        pendingSelectionDeletion = nil
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

    private func makePendingSelectionDeletion(
        selectedText: String?,
        documentContextBeforeInput: String?
    ) -> PendingSelectionDeletion? {
        guard let selectedText,
              selectedText.isEmpty == false,
              let documentContextBeforeInput,
              let trailingCharacter = documentContextBeforeInput.last,
              isHorizontalWhitespace(trailingCharacter) else {
            return nil
        }

        return PendingSelectionDeletion(
            documentContextBeforeInput: documentContextBeforeInput
        )
    }

    private func contextAfterCorrectingPendingSelectionDeletion(
        _ currentContext: String?
    ) -> String? {
        guard let pendingSelectionDeletion,
              currentContext == pendingSelectionDeletion.documentContextBeforeInput else {
            return currentContext
        }

        return String(pendingSelectionDeletion.documentContextBeforeInput.dropLast())
    }

    private func isHorizontalWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(CharacterSet.whitespaces.contains)
    }
}
