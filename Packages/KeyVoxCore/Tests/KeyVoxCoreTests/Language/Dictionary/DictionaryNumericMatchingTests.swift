import XCTest
@testable import KeyVoxCore

final class DictionaryNumericMatchingTests: XCTestCase {
    func testLeadingZeroTokenUsesCanonicalIntegerSpellingAndSource() {
        let variants = DictionaryNumericMatching.phraseVariants(for: ["001"])

        XCTAssertTrue(variants.contains { variant in
            variant.normalized == "one" && variant.numericSourceTokens == ["1"]
        })
    }

    func testNumericTokenOutsideCacheUsesFormatterSpelling() {
        XCTAssertEqual(
            DictionaryNumericMatching.tokenVariants(for: "1000"),
            ["1000", "one thousand"]
        )
    }

    func testEmbeddedNumericSegmentsExpandWithoutLosingTheirSources() {
        let variants = DictionaryNumericMatching.phraseVariants(for: ["3d2"])

        XCTAssertTrue(variants.contains { variant in
            variant.normalized == "three d two"
                && variant.numericSourceTokens == ["3", nil, "2"]
        })
    }
}
