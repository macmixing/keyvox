import XCTest
import KeyVoxCore
import KeyVoxStyleRewrite
@testable import KeyVox

@MainActor
final class MacVibesCoordinatorTests: XCTestCase {
    func testMissingModelResolvesSelectedVibeToNoneAndLeavesTextUnchanged() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettingsStore(defaults: defaults)
        settings.selectedVibe = .polished
        let transformer = FakeDictationTextTransformer()
        let coordinator = MacVibesCoordinator(
            appSettings: settings,
            textTransformer: transformer,
            isModelReady: { false }
        )

        let result = await coordinator.transform("hello", style: .polished)

        XCTAssertEqual(coordinator.selectedVibe, .none)
        XCTAssertEqual(settings.selectedVibe, .polished)
        XCTAssertEqual(result.finalText, "hello")
        XCTAssertEqual(result.styleIdentifier, StyleRewriteStyle.none.styleIdentifier)
        XCTAssertEqual(transformer.transformRequests.count, 0)
    }

    func testReadyModelTransformsSelectedVibe() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettingsStore(defaults: defaults)
        settings.selectedVibe = .casual
        let transformer = FakeDictationTextTransformer()
        transformer.resultText = "clean hello"
        let coordinator = MacVibesCoordinator(
            appSettings: settings,
            textTransformer: transformer,
            isModelReady: { true }
        )

        let result = await coordinator.processOutputText("hello")

        XCTAssertEqual(coordinator.selectedVibe, .casual)
        XCTAssertEqual(result.text, "clean hello")
        XCTAssertEqual(result.styleIdentifier, StyleRewriteStyle.casual.styleIdentifier)
        XCTAssertEqual(transformer.transformRequests.map(\.styleIdentifier), [StyleRewriteStyle.casual.styleIdentifier])
    }

    func testProcessOutputTextPassesDeterministicVariantsToTransformerRequest() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettingsStore(defaults: defaults)
        settings.selectedVibe = .casual
        let transformer = FakeDictationTextTransformer()
        let coordinator = MacVibesCoordinator(
            appSettings: settings,
            textTransformer: transformer,
            isModelReady: { true }
        )
        let context = DictationPipelineTextProcessingContext(
            rawText: "That's version one dot two dot seven.",
            baseText: "That's version:\n\n1. Dot\n2. Dot seven",
            baseParagraphsEnabled: true,
            baseListsEnabled: true,
            deterministicVariants: [
                DictationPipelineResult.DeterministicTextVariant(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "That's version one dot two dot seven"
                )
            ]
        )

        _ = await coordinator.processOutputText(context)

        XCTAssertEqual(transformer.transformRequests.count, 1)
        XCTAssertEqual(
            transformer.transformRequests[0].deterministicVariants,
            [
                StyleRewriteInputVariant(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "That's version one dot two dot seven"
                )
            ]
        )
    }

    func testAdvanceSelectedVibeIsBlockedWhenModelIsMissing() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettingsStore(defaults: defaults)
        settings.selectedVibe = .chill
        let coordinator = MacVibesCoordinator(
            appSettings: settings,
            textTransformer: FakeDictationTextTransformer(),
            isModelReady: { false }
        )

        XCTAssertEqual(coordinator.advanceSelectedVibe(), .none)
        XCTAssertEqual(settings.selectedVibe, .chill)
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "MacVibesCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

@MainActor
private final class FakeDictationTextTransformer: DictationTextTransforming {
    var resultText = "rewritten"
    private(set) var prewarmRequests: [TextTransformRequest] = []
    private(set) var transformRequests: [TextTransformRequest] = []

    func prewarm(request: TextTransformRequest) {
        prewarmRequests.append(request)
    }

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        transformRequests.append(request)
        return TextTransformResult(
            originalText: request.baseText,
            finalText: resultText,
            styleIdentifier: request.styleIdentifier,
            duration: 0,
            chunkCount: request.baseText.isEmpty ? 0 : 1,
            applied: resultText != request.baseText,
            chunkTimings: [],
            errors: [],
            processingMode: "fake"
        )
    }
}
