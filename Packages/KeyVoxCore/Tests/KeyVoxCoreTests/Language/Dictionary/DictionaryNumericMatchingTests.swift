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
}
