import Foundation
import Dispatch
import XCTest
import KeyVoxLinguistics
import KeyVoxCore
import KeyVoxCorePackageDiscoveredTests

private final class MeasuredAnalyzer: LinguisticAnalyzing, @unchecked Sendable {
    private let base: PerceptronLinguisticAnalyzer
    private let tracesOutputs: Bool
    private let lock = NSLock()
    private var calls = 0

    init(directory: URL, lexicalDatabaseDirectory: URL?, language: String) throws {
        let residentMemoryBefore = Self.residentMemoryKilobytes()
        let start = DispatchTime.now().uptimeNanoseconds
        base = try PerceptronLinguisticAnalyzer(
            modelDirectory: directory,
            lexicalDatabaseDirectory: lexicalDatabaseDirectory,
            languageCode: language
        )
        tracesOutputs = ProcessInfo.processInfo.environment["KEYVOX_LINGUISTIC_TRACE"] == "1"
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let residentMemoryAfter = Self.residentMemoryKilobytes()
        write(
            "Linguistic analyzer selected=Perceptron wordnet=\(lexicalDatabaseDirectory != nil) "
                + "language=\(language) init_ns=\(elapsed) rss_before_kb=\(residentMemoryBefore ?? -1) "
                + "rss_after_kb=\(residentMemoryAfter ?? -1)\n"
        )
    }

    func analyze(_ text: String, range: NSRange?, languageCode: String?,
                 features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
        let start = DispatchTime.now().uptimeNanoseconds
        let result = base.analyze(
            text,
            range: range,
            languageCode: languageCode,
            features: features,
            grouping: grouping
        )
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let count = lock.withLock {
            calls += 1
            return calls
        }
        if tracesOutputs {
            let tokens = result.tokens.map { token in
                "\(token.range.location):\(token.range.length),role=\(describe(token.role)),lemma=\(token.lemma ?? "-"),identity=\(token.identity),inflection=\(token.inflection)"
            }.joined(separator: ";")
            write(
                "Linguistic analysis call=\(count) ns=\(elapsed) features=\(features.rawValue) "
                    + "available=\(result.availableFeatures.rawValue) grouping=\(grouping) "
                    + "language=\(languageCode ?? "-") input=\(String(reflecting: text)) tokens=[\(tokens)]\n"
            )
        }
        return result
    }

    private func describe(_ role: LexicalRole?) -> String {
        role.map { String(describing: $0) } ?? "-"
    }

    private func write(_ message: String) {
        lock.withLock {
            FileHandle.standardError.write(Data(message.utf8))
        }
    }

    private static func residentMemoryKilobytes() -> Int? {
        guard let contents = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8),
              let line = contents.split(separator: "\n").first(where: { $0.hasPrefix("VmRSS:") }) else {
            return nil
        }
        return line.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
    }
}

private protocol DiscoveredTestRunning {
    func run()
}

private struct SwiftPMDiscoveredTestRunner: DiscoveredTestRunning {
    @available(*, deprecated, message: "Bridges SwiftPM's compatibility discovery entrypoint")
    func run() {
        XCTMain(__allDiscoveredTests())
    }
}

@main
struct ModelSelectedRunner {
    enum Failure: Error { case missingConfiguration }
    private struct HeldoutReport: Encodable {
        let input: String
        let output: String
        let availableFeatures: Int
        let tokens: [HeldoutToken]
    }

    private struct HeldoutToken: Encodable {
        let location: Int
        let length: Int
        let role: String?
        let identity: String
        let inflection: String
    }

    static func main() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["KEYVOX_LINGUISTIC_MODEL"],
              let language = environment["KEYVOX_LINGUISTIC_LANGUAGE"] else {
            throw Failure.missingConfiguration
        }
        let lexicalDatabaseDirectory = environment["KEYVOX_LEXICAL_DATABASE"].map(URL.init(fileURLWithPath:))
        let analyzer = try MeasuredAnalyzer(
            directory: URL(fileURLWithPath: path),
            lexicalDatabaseDirectory: lexicalDatabaseDirectory,
            language: language
        )
        if let inputPath = environment["KEYVOX_HELDOUT_INPUT"] {
            let input = try String(contentsOfFile: inputPath, encoding: .utf8)
            let analysis = analyzer.analyze(
                input,
                range: nil,
                languageCode: language,
                features: [.roles, .lemmas, .names, .wordBoundaries],
                grouping: .words
            )
            let output = TranscriptionPostProcessor(linguisticAnalyzer: analyzer).process(
                input,
                dictionaryEntries: [],
                renderMode: .multiline,
                languageCode: language
            )
            let report = HeldoutReport(
                input: input,
                output: output,
                availableFeatures: analysis.availableFeatures.rawValue,
                tokens: analysis.tokens.map {
                    HeldoutToken(
                        location: $0.range.location,
                        length: $0.range.length,
                        role: $0.role.map { String(describing: $0) },
                        identity: String(describing: $0.identity),
                        inflection: String(describing: $0.inflection)
                    )
                }
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
            return
        }
        TextLinguistics.$provider.withValue(analyzer) {
            let runner: any DiscoveredTestRunning = SwiftPMDiscoveredTestRunner()
            runner.run()
        }
    }
}
