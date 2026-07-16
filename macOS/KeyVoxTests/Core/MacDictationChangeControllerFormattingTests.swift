import KeyVoxCore
import KeyVoxStyleRewrite
import XCTest
@testable import KeyVox

@MainActor
final class MacDictationChangeControllerFormattingTests: XCTestCase {
    func testEveryBaselineStateTogglesOnlyRequestedControl() async {
        for baselineState in allStates {
            for kind in [DictationDeterministicControlKind.paragraphs, .lists] {
                let harness = makeHarness(state: baselineState)
                let expectedState = DictationDeterministicVariantResolver().targetState(
                    from: baselineState,
                    kind: kind
                )

                let outcome = await harness.controller.applyDeterministicChange(kind)

                XCTAssertTrue(outcome.didApply, "Expected \(kind) to apply from \(baselineState)")
                XCTAssertEqual(outcome.effectiveState, expectedState)
                XCTAssertEqual(harness.controller.activeSession?.currentDeterministicState, expectedState)
            }
        }
    }

    func testRepeatedListAndParagraphActionsToggleBackToCachedVariants() async {
        for kind in [DictationDeterministicControlKind.lists, .paragraphs] {
            let baselineState = DictationDeterministicState(
                paragraphsEnabled: false,
                listsEnabled: false
            )
            let harness = makeHarness(state: baselineState)

            let enabledOutcome = await harness.controller.applyDeterministicChange(kind)
            let disabledOutcome = await harness.controller.applyDeterministicChange(kind)

            XCTAssertTrue(enabledOutcome.didApply)
            XCTAssertTrue(disabledOutcome.didApply)
            XCTAssertEqual(disabledOutcome.effectiveState, baselineState)
            XCTAssertEqual(harness.pasteService.currentText, text(for: baselineState))
        }
    }

    func testActiveVibeRendersOnceThenUsesStateAndVibeCache() async {
        let baselineState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let harness = makeHarness(
            state: baselineState,
            style: .casual,
            currentText: "Styled plain",
            renderedVariants: [
                MacDictationRenderedVariantKey(
                    deterministicState: baselineState,
                    style: .casual
                ): "Styled plain"
            ]
        )
        harness.transformer.resultText = "Styled paragraph"

        _ = await harness.controller.applyDeterministicChange(.paragraphs)
        _ = await harness.controller.applyDeterministicChange(.paragraphs)
        _ = await harness.controller.applyDeterministicChange(.paragraphs)

        XCTAssertEqual(harness.transformer.transformRequests.count, 1)
        XCTAssertEqual(harness.pasteService.currentText, "Styled paragraph")
        XCTAssertEqual(harness.controller.activeSession?.currentStyle, .casual)
    }

    func testFormattingRetainsPreviousVibeForExistingVibeToggleBehavior() async {
        let baselineState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let harness = makeHarness(
            state: baselineState,
            style: .casual,
            previousStyle: .polished,
            currentText: "Styled plain"
        )
        harness.transformer.resultText = "Styled paragraph"

        let outcome = await harness.controller.applyDeterministicChange(.paragraphs)

        XCTAssertTrue(outcome.didApply)
        XCTAssertEqual(harness.controller.activeSession?.currentStyle, .casual)
        XCTAssertEqual(harness.controller.activeSession?.previousStyle, .polished)
    }

    func testUnavailableVibesPreservesStyleAndLeavesInsertionUnchanged() async {
        let baselineState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let harness = makeHarness(
            state: baselineState,
            style: .polished,
            previousStyle: .casual,
            currentText: "Styled plain",
            modelIsReady: false
        )

        let outcome = await harness.controller.applyDeterministicChange(.lists)

        XCTAssertFalse(outcome.didApply)
        XCTAssertEqual(outcome.effectiveState, baselineState)
        XCTAssertEqual(harness.pasteService.currentText, "Styled plain")
        XCTAssertEqual(harness.controller.activeSession?.currentDeterministicState, baselineState)
        XCTAssertEqual(harness.controller.activeSession?.currentStyle, .polished)
        XCTAssertEqual(harness.controller.activeSession?.previousStyle, .casual)
        XCTAssertTrue(harness.transformer.transformRequests.isEmpty)
        XCTAssertTrue(harness.pasteService.replacements.isEmpty)
    }

    func testAllCapsPresentationIsPreserved() async {
        let baselineState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let harness = makeHarness(
            state: baselineState,
            currentText: text(for: baselineState).uppercased(),
            displaysAllCaps: true
        )

        let outcome = await harness.controller.applyDeterministicChange(.paragraphs)
        let targetState = DictationDeterministicState(
            paragraphsEnabled: true,
            listsEnabled: false
        )

        XCTAssertTrue(outcome.didApply)
        XCTAssertEqual(harness.pasteService.currentText, text(for: targetState).uppercased())
        XCTAssertEqual(harness.controller.activeSession?.sourceText, text(for: targetState))
    }

    func testEditedInsertionInvalidatesSessionWithoutReplacement() async {
        let harness = makeHarness(
            state: DictationDeterministicState(
                paragraphsEnabled: false,
                listsEnabled: false
            )
        )
        harness.pasteService.currentText = "User edited this"

        let outcome = await harness.controller.applyDeterministicChange(.lists)

        XCTAssertFalse(outcome.didApply)
        XCTAssertEqual(
            outcome.effectiveState,
            DictationDeterministicState(
                paragraphsEnabled: false,
                listsEnabled: false
            )
        )
        XCTAssertNil(harness.controller.activeSession)
        XCTAssertTrue(harness.pasteService.replacements.isEmpty)
    }

    func testMissingInsertionReturnsNoEffectiveState() async {
        let harness = makeHarnessWithoutSession()

        let outcome = await harness.controller.applyDeterministicChange(.paragraphs)

        XCTAssertFalse(outcome.didApply)
        XCTAssertNil(outcome.effectiveState)
        XCTAssertTrue(harness.pasteService.replacements.isEmpty)
    }

    func testIdenticalTargetVariantCommitsTargetStateWithoutReplacement() async {
        let baselineState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let currentText = text(for: baselineState)
        let harness = makeHarness(
            state: baselineState,
            currentText: currentText,
            deterministicVariants: Dictionary(
                uniqueKeysWithValues: allStates.map { ($0, currentText) }
            )
        )

        let outcome = await harness.controller.applyDeterministicChange(.lists)
        let targetState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: true
        )

        XCTAssertFalse(outcome.didApply)
        XCTAssertEqual(outcome.effectiveState, targetState)
        XCTAssertEqual(harness.controller.activeSession?.currentDeterministicState, targetState)
        XCTAssertEqual(harness.controller.activeSession?.sourceText, currentText)
        XCTAssertEqual(
            harness.controller.activeSession?.renderedDeterministicVariants[
                MacDictationRenderedVariantKey(
                    deterministicState: targetState,
                    style: .none
                )
            ],
            currentText
        )
        XCTAssertTrue(harness.pasteService.replacements.isEmpty)
    }

    func testIdenticalRenderedTextRevalidatesInsertionAfterRendering() async {
        let baselineState = DictationDeterministicState(
            paragraphsEnabled: false,
            listsEnabled: false
        )
        let harness = makeHarness(
            state: baselineState,
            style: .casual,
            currentText: "Styled plain"
        )
        harness.transformer.resultText = "Styled plain"
        let pasteService = harness.pasteService
        harness.transformer.onTransform = {
            pasteService.currentText = "User edited while rendering"
        }

        let outcome = await harness.controller.applyDeterministicChange(.paragraphs)

        XCTAssertFalse(outcome.didApply)
        XCTAssertEqual(outcome.effectiveState, baselineState)
        XCTAssertNil(harness.controller.activeSession)
        XCTAssertEqual(harness.pasteService.currentText, "User edited while rendering")
        XCTAssertTrue(harness.pasteService.replacements.isEmpty)
    }

    private var allStates: [DictationDeterministicState] {
        [false, true].flatMap { paragraphsEnabled in
            [false, true].map { listsEnabled in
                DictationDeterministicState(
                    paragraphsEnabled: paragraphsEnabled,
                    listsEnabled: listsEnabled
                )
            }
        }
    }

    private func text(for state: DictationDeterministicState) -> String {
        switch (state.paragraphsEnabled, state.listsEnabled) {
        case (false, false):
            return "Plain sentence"
        case (true, false):
            return "First paragraph\n\nSecond paragraph"
        case (false, true):
            return "Items More context\n\n1. First\n2. Second"
        case (true, true):
            return "Items\n\nMore context\n\n1. First\n2. Second"
        }
    }

    private func makeHarness(
        state: DictationDeterministicState,
        style: StyleRewriteStyle = .none,
        previousStyle: StyleRewriteStyle? = nil,
        currentText: String? = nil,
        renderedVariants: [MacDictationRenderedVariantKey: String] = [:],
        displaysAllCaps: Bool = false,
        modelIsReady: Bool = true,
        deterministicVariants: [DictationDeterministicState: String]? = nil
    ) -> FormattingHarness {
        let harness = makeHarnessWithoutSession(modelIsReady: modelIsReady)
        let sourceText = text(for: state)
        let displayedText = currentText ?? sourceText
        var cachedVariants = renderedVariants
        cachedVariants[MacDictationRenderedVariantKey(
            deterministicState: state,
            style: .none
        )] = sourceText
        if style != .none {
            cachedVariants[MacDictationRenderedVariantKey(
                deterministicState: state,
                style: style
            )] = displayedText
        }
        var styleVariants: [StyleRewriteStyle: String] = [.none: sourceText]
        if style != .none {
            styleVariants[style] = displayedText
        }
        harness.controller.activeSession = MacDictationChangeSession(
            sourceText: sourceText,
            originalText: sourceText,
            currentText: displayedText,
            currentStyle: style,
            previousStyle: previousStyle,
            variants: styleVariants,
            baselineDeterministicState: state,
            currentDeterministicState: state,
            deterministicVariants: deterministicVariants ?? Dictionary(
                uniqueKeysWithValues: allStates.map { ($0, text(for: $0)) }
            ),
            renderedDeterministicVariants: cachedVariants,
            displaysAllCaps: displaysAllCaps
        )
        harness.pasteService.currentText = displayedText
        return harness
    }

    private func makeHarnessWithoutSession(modelIsReady: Bool = true) -> FormattingHarness {
        let suiteName = "MacDictationChangeControllerFormattingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let transformer = FormattingFakeTextTransformer()
        let coordinator = MacVibesCoordinator(
            appSettings: AppSettingsStore(defaults: defaults),
            textTransformer: transformer,
            isModelReady: { modelIsReady }
        )
        let pasteService = FormattingFakePasteService()
        let controller = MacDictationChangeController(
            pasteService: pasteService,
            vibesCoordinator: coordinator
        )
        return FormattingHarness(
            controller: controller,
            pasteService: pasteService,
            transformer: transformer,
            defaults: defaults,
            suiteName: suiteName
        )
    }
}

@MainActor
private final class FormattingHarness {
    let controller: MacDictationChangeController
    let pasteService: FormattingFakePasteService
    let transformer: FormattingFakeTextTransformer
    private let defaults: UserDefaults
    private let suiteName: String

    init(
        controller: MacDictationChangeController,
        pasteService: FormattingFakePasteService,
        transformer: FormattingFakeTextTransformer,
        defaults: UserDefaults,
        suiteName: String
    ) {
        self.controller = controller
        self.pasteService = pasteService
        self.transformer = transformer
        self.defaults = defaults
        self.suiteName = suiteName
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class FormattingFakePasteService: MacDictationInsertionReplacing {
    var currentText: String?
    private(set) var replacements: [(current: String, replacement: String)] = []

    func currentTextMatchesUntouchedInsertion(_ text: String) async -> Bool {
        currentText == text
    }

    func replaceUntouchedInsertion(_ currentText: String, with replacementText: String) async -> Bool {
        guard self.currentText == currentText else {
            return false
        }

        replacements.append((current: currentText, replacement: replacementText))
        self.currentText = replacementText
        return true
    }
}

@MainActor
private final class FormattingFakeTextTransformer: DictationTextTransforming {
    var resultText = "Rewritten text"
    var onTransform: (() -> Void)?
    private(set) var transformRequests: [TextTransformRequest] = []

    func prewarm(request: TextTransformRequest) {}

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        transformRequests.append(request)
        onTransform?()
        return TextTransformResult(
            originalText: request.baseText,
            finalText: resultText,
            styleIdentifier: request.styleIdentifier,
            duration: 0,
            chunkCount: 1,
            applied: resultText != request.baseText,
            chunkTimings: [],
            errors: [],
            processingMode: "fake"
        )
    }
}
