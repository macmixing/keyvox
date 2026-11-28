import Foundation
import KeyVoxTypingSimulation

/// `regression-cases`: picks a typing language's regression cases from a corpus and writes them
/// to its folder of the package's typing regression check, for the package tests to record what
/// typing them gives.
enum RegressionCasesCommand {
    static func run(_ options: HarnessCommand.RegressionCasesOptions) throws {
        guard let languageIdentifier = options.source.languageIdentifier else { throw HarnessError.usage }
        let cases = try RegressionCaseBuilder.build(
            languageIdentifier: languageIdentifier,
            corpusPaths: options.source.corpusPaths,
            caseCount: options.source.sentenceLimit,
            noiseInKeyPitches: options.source.noiseInKeyPitches,
            seed: options.source.seed
        )
        let url = TypingRegressionFixture.casesURL(
            in: URL(fileURLWithPath: options.fixturesPath, isDirectory: true),
            language: languageIdentifier
        )
        try TypingRegressionFixture.write(cases, to: url)
        print("Wrote \(cases.count) cases to \(url.path)")
    }
}
