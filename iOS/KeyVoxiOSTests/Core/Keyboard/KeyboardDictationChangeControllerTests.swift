import Foundation
import KeyVoxStyleRewrite
import Testing
import UIKit
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

        #expect(controller.hasActiveUntouchedInsertion == true)
        #expect(controller.displayedAutoParagraphsEnabled == false)
        #expect(controller.displayedListFormattingEnabled == true)
    }

    @Test func activeUntouchedInsertionClearsAfterUserEditsText() throws {
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let text = "Plain dictation."
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: text,
            baseText: text,
            selectedText: text,
            selectedStyleIdentifier: nil,
            baseParagraphsEnabled: false,
            baseListsEnabled: false,
            variants: [],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: text
                )
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
        #expect(controller.hasActiveUntouchedInsertion == true)

        documentProxy.insertText("x")

        #expect(controller.hasActiveUntouchedInsertion == false)
    }

    @Test func capsLongPressUppercasesAndRestoresUntouchedInsertion() throws {
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let text = "Plain dictation."
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: text,
            baseText: text,
            selectedText: text,
            selectedStyleIdentifier: nil,
            baseParagraphsEnabled: false,
            baseListsEnabled: false,
            variants: [],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: text
                )
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

        #expect(controller.applyCapsLongPressChange() == true)
        #expect(controller.displayedCapsTransformApplied == true)
        #expect(controller.displayedCapsTextIsUppercase == true)
        #expect(documentProxy.documentContextBeforeInput == text.uppercased())

        #expect(controller.applyCapsLongPressChange() == true)
        #expect(controller.displayedCapsTransformApplied == false)
        #expect(controller.displayedCapsTextIsUppercase == false)
        #expect(documentProxy.documentContextBeforeInput == text)
    }

    @Test func capsLongPressLowercasesAndRestoresDictationInsertedWithCapsLockEnabled() throws {
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let text = "Plain dictation."
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: text,
            baseText: text,
            selectedText: text.uppercased(),
            selectedUncappedText: text,
            selectedStyleIdentifier: nil,
            baseParagraphsEnabled: false,
            baseListsEnabled: false,
            variants: [],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: text
                )
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

        let insertion = try #require(textInputController.insertTranscriptionWithResult(text.uppercased()))
        controller.recordInsertedDictation(insertion)

        #expect(controller.displayedCapsTransformApplied == false)
        #expect(controller.displayedCapsTextIsUppercase == false)

        #expect(controller.applyCapsLongPressChange() == true)
        #expect(controller.displayedCapsTransformApplied == true)
        #expect(controller.displayedCapsTextIsUppercase == false)
        #expect(documentProxy.documentContextBeforeInput == text)

        #expect(controller.applyCapsLongPressChange() == true)
        #expect(controller.displayedCapsTransformApplied == false)
        #expect(controller.displayedCapsTextIsUppercase == false)
        #expect(documentProxy.documentContextBeforeInput == text.uppercased())
    }

    @Test func capsLongPressRestoresVibeDictationInsertedWithCapsLockEnabled() throws {
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let baseText = "Plain dictation."
        let casualText = "plain dictation."
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: baseText,
            baseText: baseText,
            selectedText: casualText.uppercased(),
            selectedUncappedText: casualText,
            selectedStyleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
            baseParagraphsEnabled: false,
            baseListsEnabled: false,
            variants: [
                DictationTextVariantArtifact(
                    styleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
                    text: casualText,
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
                    text: baseText
                )
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

        let insertion = try #require(textInputController.insertTranscriptionWithResult(casualText.uppercased()))
        controller.recordInsertedDictation(insertion)

        #expect(controller.displayedCapsTransformApplied == false)
        #expect(controller.displayedCapsTextIsUppercase == false)
        #expect(controller.applyCapsLongPressChange() == true)
        #expect(controller.displayedCapsTransformApplied == true)
        #expect(controller.displayedCapsTextIsUppercase == false)
        #expect(documentProxy.documentContextBeforeInput == casualText)

        #expect(controller.applyCapsLongPressChange() == true)
        #expect(controller.displayedCapsTransformApplied == false)
        #expect(controller.displayedCapsTextIsUppercase == false)
        #expect(documentProxy.documentContextBeforeInput == casualText.uppercased())
    }

    @Test func capsOverlayPersistsAcrossDeterministicListChange() async throws {
        let suiteName = "KeyboardDictationChangeControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(false, forKey: UserDefaultsKeys.autoParagraphsEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.listFormattingEnabled)

        let noListText = "Tasks one Alpha two Beta"
        let listText = "Tasks:\n\n1. Alpha\n2. Beta"
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: noListText,
            baseText: noListText,
            selectedText: noListText,
            selectedStyleIdentifier: nil,
            baseParagraphsEnabled: false,
            baseListsEnabled: false,
            variants: [],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: noListText
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
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

        let insertion = try #require(textInputController.insertTranscriptionWithResult(noListText))
        controller.recordInsertedDictation(insertion)
        #expect(controller.applyCapsLongPressChange() == true)

        let didApplyList = await controller.applyDeterministicLongPressChange(
            .lists,
            onProcessingStart: {},
            onProcessingEnd: {}
        )

        #expect(didApplyList == true)
        #expect(controller.displayedCapsTransformApplied == true)
        #expect(documentProxy.documentContextBeforeInput == listText.uppercased())

        #expect(controller.applyCapsLongPressChange() == true)
        #expect(documentProxy.documentContextBeforeInput == listText)
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

    @Test func reapplyingVibeAfterListReapplyUsesRenderedDeterministicCache() async throws {
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
        defaults.set(true, forKey: UserDefaultsKeys.listFormattingEnabled)

        let listText = "Tasks:\n\n1. Alpha\n2. Beta"
        let casualListText = "tasks:\n\n1. alpha\n2. beta"
        let noListText = "Tasks one Alpha two Beta"
        let casualNoListText = "tasks one alpha two beta"
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: listText,
            baseText: listText,
            selectedText: casualListText,
            selectedStyleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
            baseParagraphsEnabled: false,
            baseListsEnabled: true,
            variants: [
                DictationTextVariantArtifact(
                    styleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
                    text: casualListText,
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
                    text: noListText
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
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
        let transformer = KeyboardDictationChangeTextTransformerSpy(
            transformedText: casualNoListText
        )
        let documentProxy = KeyboardDictationChangeDocumentProxySpy()
        let textInputController = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )
        let controller = KeyboardDictationChangeController(
            textInputController: textInputController,
            appSettingsStore: KeyboardAppSettingsStore(defaults: defaults),
            artifactStore: KeyboardDictationChangeArtifactStore(defaults: defaults),
            textTransformer: transformer
        )

        let insertion = try #require(textInputController.insertTranscriptionWithResult(casualListText))
        controller.recordInsertedDictation(insertion)

        let didRemoveList = await controller.applyDeterministicLongPressChange(
            .lists,
            onProcessingStart: {},
            onProcessingEnd: {}
        )
        #expect(didRemoveList == true)
        #expect(transformer.transformCallCount == 1)

        let didRevertVibe = await controller.applyLongPressChange(
            onProcessingStart: {},
            onProcessingEnd: {}
        )
        #expect(didRevertVibe == true)
        let didReapplyList = await controller.applyDeterministicLongPressChange(
            .lists,
            onProcessingStart: {},
            onProcessingEnd: {}
        )
        #expect(didReapplyList == true)
        var processingStartCount = 0
        var processingEndCount = 0

        let didReapplyVibe = await controller.applyLongPressChange(
            onProcessingStart: { processingStartCount += 1 },
            onProcessingEnd: { processingEndCount += 1 }
        )

        #expect(didReapplyVibe == true)
        #expect(transformer.transformCallCount == 1)
        #expect(processingStartCount == 0)
        #expect(processingEndCount == 0)
    }
}

@MainActor
struct KeyboardCapsLockButtonTests {
    @Test func visualStateUsesTapLatchWhenNoDictationTransformIsActive() {
        let button = KeyboardCapsLockButton()

        button.isLocked = false
        button.isDictationCapsApplied = false
        button.isDictationCapsUppercase = false
        #expect(button.isVisuallyLocked == false)
        #expect(button.showsDictationCapsIndicator == false)

        button.isLocked = true
        #expect(button.isVisuallyLocked == true)
        #expect(button.showsDictationCapsIndicator == false)
    }

    @Test func visualStateUsesTransformedDictationCasingWhenCapsTransformIsActive() {
        let button = KeyboardCapsLockButton()

        button.isLocked = false
        button.isDictationCapsApplied = true
        button.isDictationCapsUppercase = true
        #expect(button.isVisuallyLocked == true)
        #expect(button.showsDictationCapsIndicator == true)

        button.isDictationCapsUppercase = false
        #expect(button.isVisuallyLocked == false)
        #expect(button.showsDictationCapsIndicator == true)

        button.isLocked = true
        #expect(button.isVisuallyLocked == false)

        button.isDictationCapsApplied = false
        #expect(button.isVisuallyLocked == true)
        #expect(button.showsDictationCapsIndicator == false)
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

@MainActor
private final class KeyboardDictationChangeTextTransformerSpy: DictationTextTransforming {
    private let transformedText: String
    var transformCallCount = 0

    init(transformedText: String) {
        self.transformedText = transformedText
    }

    func prewarm(request: TextTransformRequest) {}

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        transformCallCount += 1
        return TextTransformResult(
            originalText: request.baseText,
            finalText: transformedText,
            styleIdentifier: request.styleIdentifier,
            duration: 0,
            chunkCount: 1,
            applied: true,
            chunkTimings: [],
            errors: [],
            processingMode: nil
        )
    }
}
