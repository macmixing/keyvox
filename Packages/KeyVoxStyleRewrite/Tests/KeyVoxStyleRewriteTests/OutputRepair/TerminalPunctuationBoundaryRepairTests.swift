import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class TerminalPunctuationBoundaryRepairTests: LinguisticAnalyzerTestCase {
    func testTerminalPunctuationBoundaryRepairRestoresSourceEllipsis() {
        let inlineOutput = TerminalPunctuationBoundaryRepair().repair(
            original: "Well… I agree.",
            rewritten: "well i agree"
        )
        let terminalOutput = TerminalPunctuationBoundaryRepair().repair(
            original: "Wait…",
            rewritten: "wait"
        )

        XCTAssertEqual(inlineOutput, "well… i agree")
        XCTAssertEqual(terminalOutput, "wait…")
    }

    func testTerminalPunctuationBoundaryRepairRestoresSourceBoundaryExclamation() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "That is wild! Are we shipping this?",
            rewritten: "that is wild. are we shipping this?"
        )

        XCTAssertEqual(output, "that is wild! are we shipping this?")
    }

    func testTerminalPunctuationBoundaryRepairPreservesRewrittenParagraphBreak() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "That is wild! Are we shipping this?",
            rewritten: "that is wild.\n\nare we shipping this?"
        )

        XCTAssertEqual(output, "that is wild!\n\nare we shipping this?")
    }

    func testTerminalPunctuationBoundaryRepairRestoresTerminalSourceExclamation() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "Ship it!",
            rewritten: "ship it"
        )

        XCTAssertEqual(output, "ship it!")
    }

    func testTerminalPunctuationBoundaryRepairRestoresTerminalSourceQuestionExclamationCluster() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "What the hell is wrong with you?!",
            rewritten: "what the hell is wrong with you!"
        )

        XCTAssertEqual(output, "what the hell is wrong with you?!")
    }

    func testTerminalPunctuationBoundaryRepairRestoresTerminalSourceExclamationChangedToQuestion() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "Hey man? Are you okay!",
            rewritten: "Hey man? Are you okay?"
        )

        XCTAssertEqual(output, "Hey man? Are you okay!")
    }

    func testTerminalPunctuationBoundaryRepairDoesNotRestoreWithoutSourceExclamation() {
        let output = TerminalPunctuationBoundaryRepair().repair(
            original: "Ship it.",
            rewritten: "ship it"
        )

        XCTAssertEqual(output, "ship it")
    }
}
