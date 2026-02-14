import Foundation
import Testing
@testable import KeyVox

struct ListRendererTests {
    @Test
    func rendersMultilineWithLeadInColonAndTrailingText() {
        let renderer = ListRenderer()
        let list = DetectedList(
            leadingText: "Here is the plan",
            items: [
                DetectedListItem(spokenIndex: 1, content: "Get dog food"),
                DetectedListItem(spokenIndex: 2, content: "Charge phone"),
            ],
            trailingText: "Then we rest"
        )

        let rendered = renderer.render(list, mode: .multiline)
        #expect(rendered == "Here is the plan:\n1. Get dog food\n2. Charge phone\nThen we rest")
    }

    @Test
    func rendersSingleLineInlineWithSemicolons() {
        let renderer = ListRenderer()
        let list = DetectedList(
            leadingText: "Tasks",
            items: [
                DetectedListItem(spokenIndex: 1, content: "Call vet"),
                DetectedListItem(spokenIndex: 2, content: "Buy food"),
            ],
            trailingText: "done"
        )

        let rendered = renderer.render(list, mode: .singleLineInline)
        #expect(rendered == "Tasks: 1. Call vet; 2. Buy food done")
    }
}
