import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class StyleRewriteInputVariantSelectionTests: XCTestCase {
    func testRewriteInputVariantSelectionUsesNoListVersionVariant() {
        let baseText = "That's version:\n\n1. Dot\n2. Dot seven"
        let selected = StyleRewriteInputVariantSelection.baseText(
            for: .casual,
            baseText: baseText,
            deterministicVariants: [
                StyleRewriteInputVariant(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "That's version one dot two dot seven"
                ),
                StyleRewriteInputVariant(
                    paragraphsEnabled: true,
                    listsEnabled: true,
                    text: baseText
                ),
            ]
        )

        XCTAssertEqual(selected, "That's version one dot two dot seven")
    }

    func testRewriteInputVariantSelectionIgnoresNonVersionNumberFormatting() {
        let baseText = "I paid:\n\n5. Three dollars"
        let selected = StyleRewriteInputVariantSelection.baseText(
            for: .casual,
            baseText: baseText,
            deterministicVariants: [
                StyleRewriteInputVariant(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "I paid five point three dollars"
                ),
            ]
        )

        XCTAssertEqual(selected, baseText)
    }
}
