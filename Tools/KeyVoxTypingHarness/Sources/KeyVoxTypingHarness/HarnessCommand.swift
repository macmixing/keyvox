import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// Parsed command line for the three harness commands.
enum HarnessCommand {
    struct PlanSource {
        var corpusPaths: [String] = []
        var planPath: String?
        var sentenceLimit = 400
        var noiseInKeyPitches = 0.25
        var seed: UInt64 = 1
        /// The bundled typing language a plan built from a corpus types; English when nil.
        var languageIdentifier: String?
    }

    struct EvaluateOptions {
        var source = PlanSource()
        var usesTouches = true
        var failuresPath: String?
        var parameters = NoisyChannelCorrector.standardParameters
    }

    struct TuneOptions {
        var tuningPlanPaths: [String] = []
        var holdoutPlanPaths: [String] = []
        var passes = 3
    }

    struct PlanOptions {
        var source = PlanSource()
        var outputPath = ""
    }

    struct CompareOptions {
        var planPath = ""
        var appleResultsPath: String?
        var disagreementsPath: String?
        var parameters = NoisyChannelCorrector.standardParameters
        /// Nil types every tap on the key it hits.
        var contestedTaps: ContestedTapPolicy.Parameters? = ContestedTapPolicy.standardParameters
        /// The user's own words and phrases.
        var personalWords: [String] = []
        /// Names the system knows, such as contact names.
        var knownNames: [String] = []
        /// Where to write the typed text of every sentence, in the Apple results format.
        var textsPath: String?
    }

    struct BarsOptions {
        var probesPath = ""
        var outputPath = ""
        var parameters = NoisyChannelCorrector.standardParameters
        /// The user's own words and phrases.
        var personalWords: [String] = []
        /// Names the system knows, such as contact names.
        var knownNames: [String] = []
    }

    struct SwipeLexiconOptions {
        var languageIdentifier = "en"
        var outputPath = ""
        /// Where to write the dictionary's words as a unigram list, if anywhere.
        var wordsPath: String?
    }

    struct SwipeAccuracyOptions {
        var swipesPath = ""
        var layoutPath = ""
        var limit: Int?
        /// Context weights to rank with; none ranks with the bundled one.
        var contextWeights: [Double] = []
        var usesContext = true
        var calibratesPersonalWords = false
    }

    struct SwipeGateOptions {
        /// The typing plan whose sentences the simulated fingers tap.
        var planPath: String?
        var minimumTaps = 1_000_000
        var swipesPath: String?
        var layoutPath: String?
    }

    struct RegressionCasesOptions {
        /// The corpus to pick from, how many cases to pick (`--sentences`), and the finger noise.
        var source = PlanSource(sentenceLimit: 30, noiseInKeyPitches: 0.3)
        var languageIdentifier = ""
        /// The folder holding every language's regression check.
        var fixturesPath = ""
    }

    struct ExplainOptions {
        var typedWord = ""
        var touches: [CGPoint] = []
        /// Newest first.
        var previousWords: [String] = []
        var parameters = NoisyChannelCorrector.standardParameters
        /// The user's own words and phrases.
        var personalWords: [String] = []
        /// The word typed after the typed word, to reconsider the typed word with it.
        var followingWord: String?
        /// The bundled typing language to type in.
        var languageIdentifier = "en"
    }

    case evaluate(EvaluateOptions)
    case plan(PlanOptions)
    case compare(CompareOptions)
    case bars(BarsOptions)
    case tune(TuneOptions)
    case explain(ExplainOptions)
    case swipeLexicon(SwipeLexiconOptions)
    case swipeAccuracy(SwipeAccuracyOptions)
    case swipeGate(SwipeGateOptions)
    case regressionCases(RegressionCasesOptions)

    static let usage = """
    usage:
      KeyVoxTypingHarness evaluate (--corpus <path>... [--language <id>] | --plan <path>)
                                   [--sentences <count>] [--noise <key pitches>] [--seed <value>]
                                   [--no-touches] [--failures <tsv-path>] [--param <name>=<value>...]
      KeyVoxTypingHarness plan --corpus <path>... --output <path> [--language <id>]
                               [--sentences <count>] [--noise <key pitches>] [--seed <value>]
      KeyVoxTypingHarness compare --plan <path> [--apple <results-json>] [--disagreements <tsv-path>]
                                  [--param <name>=<value>...]
                                  [--no-contested-taps | --contested-param <name>=<value>...]
                                  [--personal <word or phrase,...>] [--known-names <word,...>]
                                  [--texts <json-path>]
      KeyVoxTypingHarness bars --probes <json-path> --output <json-path> [--param <name>=<value>...]
                               [--personal <word or phrase,...>] [--known-names <word,...>]
      KeyVoxTypingHarness tune --tune-plan <path>... [--holdout-plan <path>...] [--passes <count>]
      KeyVoxTypingHarness explain [--word <typed>] [--touches "x,y x,y ..."] [--previous <newest,older,...>]
                                  [--following <next word>] [--personal <word or phrase,...>] [--language <id>]
                                  [--param <name>=<value>...]
      KeyVoxTypingHarness swipe-lexicon --output <kvsl-path> [--words <tsv-path>] [--language <id>]
      KeyVoxTypingHarness swipe-accuracy --swipes <jsonl-path> --layout <layout-json> [--limit <count>]
                                         [--context-weights <w,w,...>] [--no-context] [--calibrate-personal]
      KeyVoxTypingHarness swipe-gate [--plan <path> [--taps <count>]] [--swipes <jsonl-path> --layout <layout-json>]
      KeyVoxTypingHarness regression-cases --language <id> --corpus <path>... --fixtures <folder>
                                           [--sentences <count>] [--noise <key pitches>] [--seed <value>]
    """

    init(arguments: [String]) throws {
        guard let command = arguments.first else { throw HarnessError.usage }
        var remaining = arguments.dropFirst()
        switch command {
        case "evaluate":
            var options = EvaluateOptions()
            while let flag = remaining.popFirst() {
                if try Self.parseSource(flag, into: &options.source, remaining: &remaining) { continue }
                switch flag {
                case "--no-touches": options.usesTouches = false
                case "--failures": options.failuresPath = try Self.value(after: flag, in: &remaining)
                case "--param":
                    try Self.applyParameter(try Self.value(after: flag, in: &remaining), to: &options.parameters)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.source.corpusPaths.isEmpty == false || options.source.planPath != nil else {
                throw HarnessError.usage
            }
            self = .evaluate(options)
        case "plan":
            var options = PlanOptions()
            while let flag = remaining.popFirst() {
                if try Self.parseSource(flag, into: &options.source, remaining: &remaining) { continue }
                switch flag {
                case "--output": options.outputPath = try Self.value(after: flag, in: &remaining)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.source.corpusPaths.isEmpty == false, options.outputPath.isEmpty == false else {
                throw HarnessError.usage
            }
            self = .plan(options)
        case "compare":
            var options = CompareOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--plan": options.planPath = try Self.value(after: flag, in: &remaining)
                case "--apple": options.appleResultsPath = try Self.value(after: flag, in: &remaining)
                case "--disagreements":
                    options.disagreementsPath = try Self.value(after: flag, in: &remaining)
                case "--param":
                    try Self.applyParameter(try Self.value(after: flag, in: &remaining), to: &options.parameters)
                case "--no-contested-taps": options.contestedTaps = nil
                case "--contested-param":
                    guard var contestedTaps = options.contestedTaps else { throw HarnessError.invalidValue(flag) }
                    try Self.applyContestedParameter(try Self.value(after: flag, in: &remaining), to: &contestedTaps)
                    options.contestedTaps = contestedTaps
                case "--personal":
                    options.personalWords = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map(String.init)
                case "--known-names":
                    options.knownNames = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map(String.init)
                case "--texts": options.textsPath = try Self.value(after: flag, in: &remaining)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.planPath.isEmpty == false else { throw HarnessError.usage }
            self = .compare(options)
        case "bars":
            var options = BarsOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--probes": options.probesPath = try Self.value(after: flag, in: &remaining)
                case "--output": options.outputPath = try Self.value(after: flag, in: &remaining)
                case "--param":
                    try Self.applyParameter(try Self.value(after: flag, in: &remaining), to: &options.parameters)
                case "--personal":
                    options.personalWords = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map(String.init)
                case "--known-names":
                    options.knownNames = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map(String.init)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.probesPath.isEmpty == false, options.outputPath.isEmpty == false else {
                throw HarnessError.usage
            }
            self = .bars(options)
        case "tune":
            var options = TuneOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--tune-plan": options.tuningPlanPaths.append(try Self.value(after: flag, in: &remaining))
                case "--holdout-plan": options.holdoutPlanPaths.append(try Self.value(after: flag, in: &remaining))
                case "--passes":
                    guard let passes = Int(try Self.value(after: flag, in: &remaining)), passes > 0 else {
                        throw HarnessError.invalidValue(flag)
                    }
                    options.passes = passes
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.tuningPlanPaths.isEmpty == false else { throw HarnessError.usage }
            self = .tune(options)
        case "explain":
            var options = ExplainOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--word": options.typedWord = try Self.value(after: flag, in: &remaining)
                case "--touches":
                    options.touches = try Self.value(after: flag, in: &remaining)
                        .split(separator: " ")
                        .map { pair in
                            let parts = pair.split(separator: ",").compactMap { Double($0) }
                            guard parts.count == 2 else { throw HarnessError.invalidValue(flag) }
                            return CGPoint(x: parts[0], y: parts[1])
                        }
                case "--previous":
                    options.previousWords = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map(String.init)
                case "--personal":
                    options.personalWords = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map(String.init)
                case "--following": options.followingWord = try Self.value(after: flag, in: &remaining)
                case "--language": options.languageIdentifier = try Self.value(after: flag, in: &remaining)
                case "--param":
                    try Self.applyParameter(try Self.value(after: flag, in: &remaining), to: &options.parameters)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.typedWord.isEmpty == false || options.previousWords.isEmpty == false else {
                throw HarnessError.usage
            }
            self = .explain(options)
        case "swipe-lexicon":
            var options = SwipeLexiconOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--output": options.outputPath = try Self.value(after: flag, in: &remaining)
                case "--words": options.wordsPath = try Self.value(after: flag, in: &remaining)
                case "--language": options.languageIdentifier = try Self.value(after: flag, in: &remaining)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.outputPath.isEmpty == false else { throw HarnessError.usage }
            self = .swipeLexicon(options)
        case "swipe-accuracy":
            var options = SwipeAccuracyOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--swipes": options.swipesPath = try Self.value(after: flag, in: &remaining)
                case "--layout": options.layoutPath = try Self.value(after: flag, in: &remaining)
                case "--limit":
                    guard let limit = Int(try Self.value(after: flag, in: &remaining)), limit > 0 else {
                        throw HarnessError.invalidValue(flag)
                    }
                    options.limit = limit
                case "--context-weights":
                    options.contextWeights = try Self.value(after: flag, in: &remaining)
                        .split(separator: ",").map { value in
                            guard let weight = Double(value) else { throw HarnessError.invalidValue(flag) }
                            return weight
                        }
                case "--no-context": options.usesContext = false
                case "--calibrate-personal": options.calibratesPersonalWords = true
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.swipesPath.isEmpty == false, options.layoutPath.isEmpty == false else { throw HarnessError.usage }
            self = .swipeAccuracy(options)
        case "swipe-gate":
            var options = SwipeGateOptions()
            while let flag = remaining.popFirst() {
                switch flag {
                case "--plan": options.planPath = try Self.value(after: flag, in: &remaining)
                case "--taps":
                    guard let taps = Int(try Self.value(after: flag, in: &remaining)), taps > 0 else {
                        throw HarnessError.invalidValue(flag)
                    }
                    options.minimumTaps = taps
                case "--swipes": options.swipesPath = try Self.value(after: flag, in: &remaining)
                case "--layout": options.layoutPath = try Self.value(after: flag, in: &remaining)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.planPath != nil || (options.swipesPath != nil && options.layoutPath != nil) else {
                throw HarnessError.usage
            }
            self = .swipeGate(options)
        case "regression-cases":
            var options = RegressionCasesOptions()
            while let flag = remaining.popFirst() {
                if flag != "--plan", try Self.parseSource(flag, into: &options.source, remaining: &remaining) { continue }
                switch flag {
                case "--language": options.languageIdentifier = try Self.value(after: flag, in: &remaining)
                case "--fixtures": options.fixturesPath = try Self.value(after: flag, in: &remaining)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.source.corpusPaths.isEmpty == false, options.languageIdentifier.isEmpty == false,
                  options.fixturesPath.isEmpty == false else {
                throw HarnessError.usage
            }
            self = .regressionCases(options)
        default:
            throw HarnessError.usage
        }
    }

    private static func parseSource(
        _ flag: String,
        into source: inout PlanSource,
        remaining: inout ArraySlice<String>
    ) throws -> Bool {
        switch flag {
        case "--corpus":
            source.corpusPaths.append(try value(after: flag, in: &remaining))
        case "--plan":
            source.planPath = try value(after: flag, in: &remaining)
        case "--sentences":
            guard let count = Int(try value(after: flag, in: &remaining)), count > 0 else {
                throw HarnessError.invalidValue(flag)
            }
            source.sentenceLimit = count
        case "--noise":
            guard let noise = Double(try value(after: flag, in: &remaining)), noise >= 0 else {
                throw HarnessError.invalidValue(flag)
            }
            source.noiseInKeyPitches = noise
        case "--seed":
            guard let seed = UInt64(try value(after: flag, in: &remaining)) else {
                throw HarnessError.invalidValue(flag)
            }
            source.seed = seed
        case "--language":
            source.languageIdentifier = try value(after: flag, in: &remaining)
        default:
            return false
        }
        return true
    }

    private static func applyParameter(
        _ assignment: String,
        to parameters: inout NoisyChannelCorrector.Parameters
    ) throws {
        let parts = assignment.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let value = Double(parts[1]),
              let dimension = ParameterSearch.dimensions.first(where: { $0.name == parts[0] }) else {
            throw HarnessError.invalidValue("--param \(assignment)")
        }
        parameters[keyPath: dimension.keyPath] = value
    }

    private static func applyContestedParameter(
        _ assignment: String,
        to parameters: inout ContestedTapPolicy.Parameters
    ) throws {
        let parts = assignment.split(separator: "=", maxSplits: 1).map(String.init)
        let keyPaths: [String: WritableKeyPath<ContestedTapPolicy.Parameters, Double>] = [
            "boundaryMaximumDistance": \.boundaryMaximumDistance,
            "controlMaximumDistance": \.controlMaximumDistance,
            "touchStandardDeviation": \.touchStandardDeviation,
            "languageWeight": \.languageWeight,
            "boundaryThreshold": \.boundaryThreshold,
        ]
        guard parts.count == 2, let value = Double(parts[1]), let keyPath = keyPaths[parts[0]] else {
            throw HarnessError.invalidValue("--contested-param \(assignment)")
        }
        parameters[keyPath: keyPath] = value
    }

    private static func value(
        after flag: String,
        in remaining: inout ArraySlice<String>
    ) throws -> String {
        guard let value = remaining.popFirst() else { throw HarnessError.invalidValue(flag) }
        return value
    }
}

extension HarnessCommand.PlanSource {
    func resolvePlan() throws -> TypingPlan {
        if let planPath { return try TypingPlan.load(from: planPath) }
        return try TypingPlanBuilder.build(
            corpusPaths: corpusPaths,
            sentenceLimit: sentenceLimit,
            noiseInKeyPitches: noiseInKeyPitches,
            seed: seed,
            languageIdentifier: languageIdentifier
        )
    }
}

enum HarnessError: Error, CustomStringConvertible {
    case usage
    case unknownFlag(String)
    case invalidValue(String)
    case unreadableCorpus(String)
    case planMismatch(String)

    var description: String {
        switch self {
        case .usage:
            return HarnessCommand.usage
        case .unknownFlag(let flag):
            return "unknown flag \(flag)\n\(HarnessCommand.usage)"
        case .invalidValue(let flag):
            return "missing or invalid value for \(flag)"
        case .unreadableCorpus(let path):
            return "could not read corpus at \(path)"
        case .planMismatch(let detail):
            return "results do not match the plan: \(detail)"
        }
    }
}
