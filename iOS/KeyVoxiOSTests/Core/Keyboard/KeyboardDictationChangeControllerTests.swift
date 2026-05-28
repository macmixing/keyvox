import Foundation
import KeyVoxStyleRewrite
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyboardDictationChangeControllerTests {
    @Test func paragraphIndicatorUsesArtifactBaseStateForListOnlyDictation() throws {
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(false, forKey: UserDefaultsKeys.autoParagraphsEnabled)
        defaults.set(true, forKey: UserDefaultsKeys.listFormattingEnabled)

        let listText = "1. Alpha\n2. Beta"
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: listText,
            baseText: listText,
            selectedText: listText,
            selectedStyleIdentifier: nil,
            baseParagraphsEnabled: false,
            baseListsEnabled: true,
            variants: [],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: true,
                    text: listText
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: true,
                    listsEnabled: true,
                    text: listText
                ),
            ],
            inferenceDuration: 0,
            textTransformationDuration: 0,
            createdAt: Date()
        )
        defaults.set(
            try JSONEncoder().encode(artifact),
            forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData
        )

        let documentProxy = KeyboardDictationChangeDocumentProxySpy()
        let textInputController = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )
        let controller = KeyboardDictationChangeController(
            textInputController: textInputController,
            appSettingsStore: KeyboardAppSettingsStore(defaults: defaults),
            artifactStore: KeyboardDictationChangeArtifactStore(defaults: defaults)
        )

        let insertion = try #require(textInputController.insertTranscriptionWithResult(listText))
        controller.recordInsertedDictation(insertion)

        #expect(controller.displayedAutoParagraphsEnabled == false)
        #expect(controller.displayedListFormattingEnabled == true)
    }

    @Test func deterministicNoOpDoesNotStartProcessingForVibeInsertion() async throws {
        setenv("KEYVOX_BYPASS_VIBES_TRIAL", "1", 1)
        defer {
            unsetenv("KEYVOX_BYPASS_VIBES_TRIAL")
        }
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(false, forKey: UserDefaultsKeys.autoParagraphsEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.listFormattingEnabled)

        let text = "Plain dictation."
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: text,
            baseText: text,
            selectedText: text,
            selectedStyleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
            baseParagraphsEnabled: false,
            baseListsEnabled: false,
            variants: [
                DictationTextVariantArtifact(
                    styleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
                    text: text,
                    duration: 0,
                    chunkCount: 1,
                    applied: true,
                    errors: []
                )
            ],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: text
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: true,
                    listsEnabled: false,
                    text: text
                ),
            ],
            inferenceDuration: 0,
            textTransformationDuration: 0,
            createdAt: Date()
        )
        defaults.set(
            try JSONEncoder().encode(artifact),
            forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData
        )

        let documentProxy = KeyboardDictationChangeDocumentProxySpy()
        let textInputController = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )
        let controller = KeyboardDictationChangeController(
            textInputController: textInputController,
            appSettingsStore: KeyboardAppSettingsStore(defaults: defaults),
            artifactStore: KeyboardDictationChangeArtifactStore(defaults: defaults)
        )

        let insertion = try #require(textInputController.insertTranscriptionWithResult(text))
        controller.recordInsertedDictation(insertion)
        var processingStartCount = 0
        var processingEndCount = 0

        let didApply = await controller.applyDeterministicLongPressChange(
            .paragraphs,
            onProcessingStart: { processingStartCount += 1 },
            onProcessingEnd: { processingEndCount += 1 }
        )

        #expect(didApply == false)
        #expect(processingStartCount == 0)
        #expect(processingEndCount == 0)
    }
}

private final class KeyboardDictationChangeDocumentProxySpy: KeyboardTextDocumentProxying {
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var hasText = false
    var selectedText: String?

    func insertText(_ text: String) {
        documentContextBeforeInput = (documentContextBeforeInput ?? "") + text
        hasText = documentContextBeforeInput?.isEmpty == false
    }

    func deleteBackward() {
        guard let context = documentContextBeforeInput,
              context.isEmpty == false else {
            return
        }

        documentContextBeforeInput = String(context.dropLast())
        hasText = documentContextBeforeInput?.isEmpty == false
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {}
}
