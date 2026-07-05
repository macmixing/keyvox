import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

@MainActor
final class StyleRewriteTextTransformerTests: XCTestCase {
    func testStyleRewriteTransformerMapsBackendFailureWithoutClaimingVibeSuccess() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note this needs cleanup."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(failingChunkIndexes: [0])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.generationFailed])
    }

    @MainActor

    func testStyleRewriteTransformerRepairsCasualDecimalDriftFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "I'm pretty sure we reverted five point five three yesterday."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "I'm pretty sure we reverted 5:53 yesterday."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "I'm pretty sure we reverted 5.53 yesterday.")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor

    func testStyleRewriteTransformerRepairsCasualTerminalPunctuationDriftFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Hey man? Are you okay!"
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "Hey man? Are you okay?"
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "Hey man? Are you okay!")
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor

    func testStyleRewriteTransformerUsesNoListVersionVariantForModelInput() async throws {
        let listText = "That's version:\n\n1. Dot\n2. Dot seven"
        let noListText = "That's version one dot two dot seven"
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: listText,
            deterministicVariants: [
                StyleRewriteInputVariant(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: noListText
                ),
                StyleRewriteInputVariant(
                    paragraphsEnabled: true,
                    listsEnabled: true,
                    text: listText
                )
            ]
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { modelRequest in
                XCTAssertEqual(modelRequest.baseText, noListText)
                return StyleRewriteTestChunkResponder()
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.originalText, listText)
        XCTAssertEqual(result.finalText, "That's version 1.2.7")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor

    func testStyleRewriteTransformerRepairsPolishedChangedNumberEvidenceFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "I'm pretty sure we reverted five point five three yesterday."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "I'm pretty sure we reverted 5.33 yesterday."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "I'm pretty sure we reverted 5.53 yesterday.")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model")
    }

    @MainActor

    func testStyleRewriteTransformerRepairsCasualChangedMoneyEvidenceFromOriginalDictation() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "That was nine hundred and two dollars."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "That was $2."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "That was $902.")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup")
    }

    @MainActor

    func testStyleRewriteTransformerRepairsPolishedAddressOrdinalDrift() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "She said her address was eleven thirty seven North Twelfth Street."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "She said her address was 1137 North 2nd Street."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "She said her address was 1137 North 12th Street.")
        XCTAssertTrue(result.applied)
    }

    @MainActor

    func testStyleRewriteTransformerMapsTypedLocalBackendFailure() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note this needs cleanup."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(typedError: .modelNotInstalled)
            }
        )

        let result = await transformer.transform(request)

        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelNotInstalled])
    }

    @MainActor

    func testStyleRewriteTransformerFallsBackWhenModelLeaksPromptInstructions() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Okay, so I guess we're gonna have to just record this dictated text."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "Okay Okay, so I guess we're gonna have to just record this dictated text. \(StyleRewriteDictationConfiguration.casualLoRASystemPrompt)"
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.promptLeakDetected])
        XCTAssertEqual(result.processingMode, "local-model-prompt-leak-fallback")
    }

    @MainActor

    func testChillUsesHeuristicTextButDoesNotClaimFullVibeSuccessWhenCleanupFails() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Um hey, this is cool."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(typedError: .modelLoadFailed("missing"))
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "um hey this is cool")
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelLoadFailed])
        XCTAssertEqual(result.processingMode, "local-model-cleanup-failed+heuristic")
    }

    @MainActor

    func testChillRestoresSourceExclamationBoundaryAfterHeuristicFormatting() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "That is wild!"
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "That is wild."
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "that is wild!")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup+heuristic")
    }

    @MainActor

    func testChillRestoresSourceQuestionExclamationClusterAfterHeuristicFormatting() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "What the hell is wrong with you?!"
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: StyleRewriteTestWordTokenCounter(),
            chunkResponderProvider: { _ in
                StyleRewriteTestChunkResponder(responses: [
                    0: "What the hell is wrong with you!"
                ])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "what the hell is wrong with you?!")
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.processingMode, "local-model-cleanup+heuristic")
    }
}
