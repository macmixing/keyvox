import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class DictationUtteranceArtifactTests: XCTestCase {
    func testDictationUtteranceArtifactRoundTripsThroughJSON() throws {
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: "raw",
            baseText: "base",
            selectedText: "styled",
            selectedUncappedText: "styled before caps",
            selectedStyleIdentifier: "test-style",
            baseParagraphsEnabled: false,
            baseListsEnabled: true,
            variants: [
                DictationTextVariantArtifact(
                    styleIdentifier: "test-style",
                    text: "styled",
                    duration: 0.25,
                    chunkCount: 2,
                    applied: true,
                    errors: ["fallback"]
                )
            ],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "base"
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: true,
                    listsEnabled: true,
                    text: "base\n\nlisted"
                ),
            ],
            inferenceDuration: 0.5,
            textTransformationDuration: 0.25,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded, artifact)
        XCTAssertEqual(decoded.selectedUncappedText, "styled before caps")
        XCTAssertEqual(decoded.baseParagraphsEnabled, false)
        XCTAssertEqual(decoded.baseListsEnabled, true)
    }

    func testDictationUtteranceArtifactDecodesMissingDeterministicVariantsAsEmpty() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "rawText": "raw",
          "baseText": "base",
          "selectedText": "styled",
          "selectedStyleIdentifier": "test-style",
          "variants": [],
          "inferenceDuration": 0.5,
          "textTransformationDuration": 0.25,
          "createdAt": 0
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded.deterministicVariants, [])
        XCTAssertNil(decoded.selectedUncappedText)
        XCTAssertNil(decoded.baseParagraphsEnabled)
        XCTAssertNil(decoded.baseListsEnabled)
    }
}
