import Foundation
import KeyVoxPredictiveKeyboard
import KeyVoxTypingLanguageCatalog
import KeyVoxTypingSimulation
import XCTest

/// The typing regression check: every bundled typing language types its cases in
/// `Fixtures/typing_regression/<language>` through the typing session, as
/// `Tools/KeyVoxTypingHarness compare` types a plan, and must leave exactly the text and
/// suggestion bars recorded in its `expected.jsonl`. With `KEYVOX_RECORD_TYPING_REGRESSION=1`
/// set, the test records what typing gives instead, into the source folder.
final class TypingRegressionTests: XCTestCase {
    private static let recordVariable = "KEYVOX_RECORD_TYPING_REGRESSION"
    private static let fixtureFolder = "Fixtures/typing_regression"

    func testEveryBundledTypingLanguageHasRegressionCases() throws {
        let bundled = try TypingLanguageCatalog.bundled().languages.map(\.identifier)
        let covered = try TypingRegressionFixture.languages(in: Self.bundledFixtures())
        XCTAssertFalse(bundled.isEmpty)
        for language in bundled where covered.contains(language) == false {
            XCTFail("\(language) has no typing regression cases; build them with KeyVoxTypingHarness regression-cases")
        }
        for language in covered where bundled.contains(language) == false {
            XCTFail("\(language) has typing regression cases but is not a bundled typing language")
        }
    }

    func testEveryTypingLanguageTypesItsCasesAsRecorded() throws {
        let recording = ProcessInfo.processInfo.environment[Self.recordVariable] == "1"
        let fixtures = try Self.bundledFixtures()
        for language in try TypingRegressionFixture.languages(in: fixtures) {
            let cases = try TypingRegressionFixture.read(
                TypingRegressionCase.self,
                from: TypingRegressionFixture.casesURL(in: fixtures, language: language)
            )
            let typer = try Self.typer(for: language)
            let outcomes = try cases.map { typingCase in
                TypingRegressionOutcome(try typer.type(words: typingCase.words, taps: typingCase.taps, barsAt: typingCase.bars))
            }
            if recording {
                try TypingRegressionFixture.write(
                    outcomes,
                    to: TypingRegressionFixture.expectedURL(in: Self.sourceFixtures, language: language)
                )
                continue
            }
            let expectedURL = TypingRegressionFixture.expectedURL(in: fixtures, language: language)
            guard FileManager.default.fileExists(atPath: expectedURL.path) else {
                XCTFail("\(language) has no recorded outcomes; record them with \(Self.recordVariable)=1")
                continue
            }
            let expected = try TypingRegressionFixture.read(TypingRegressionOutcome.self, from: expectedURL)
            XCTAssertEqual(expected.count, cases.count, "\(language): one recorded outcome per case")
            for (index, (typingCase, outcome)) in zip(cases, outcomes).enumerated() {
                guard let recorded = expected.indices.contains(index) ? expected[index] : nil else { continue }
                for message in TypingRegressionDifference.messages(
                    language: language,
                    caseNumber: index + 1,
                    typingCase: typingCase,
                    expected: recorded,
                    actual: outcome
                ) {
                    XCTFail(message)
                }
            }
        }
    }

    /// Types in `language` on its default letter layout with the shipping settings and no
    /// words of the user's.
    private static func typer(for language: String) throws -> SessionTyper {
        let engine = try PredictiveEngine(language: TypingLanguage.bundled(identifier: language))
        let layout = KeyboardLayoutModel(language: engine.language)
        let computer = PredictionComputer(engine: engine)
        computer.updateKeyboardGeometry(layout.predictionGeometry, keyboardSize: layout.keyboardSize)
        return SessionTyper(
            computer: computer,
            typingLanguage: engine.language,
            layout: layout,
            contestedTaps: ContestedTapPolicy(parameters: ContestedTapPolicy.standardParameters)
        )
    }

    private static func bundledFixtures() throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: fixtureFolder, withExtension: nil))
    }

    private static var sourceFixtures: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(fixtureFolder, isDirectory: true)
    }
}
