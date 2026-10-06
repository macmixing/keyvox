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
    }

    struct EvaluateOptions {
        var source = PlanSource()
        var usesTouches = true
        var failuresPath: String?
        var decider = CorrectionEvaluator.Decider.channel(NoisyChannelCorrector.standardParameters)
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
        var appleResultsPath = ""
        var disagreementsPath: String?
        var decider = CorrectionEvaluator.Decider.channel(NoisyChannelCorrector.standardParameters)
    }

    case evaluate(EvaluateOptions)
    case plan(PlanOptions)
    case compare(CompareOptions)
    case tune(TuneOptions)

    static let usage = """
    usage:
      KeyVoxTypingHarness evaluate (--corpus <path>... | --plan <path>)
                                   [--sentences <count>] [--noise <key pitches>] [--seed <value>]
                                   [--decider july|channel] [--no-touches] [--failures <tsv-path>]
      KeyVoxTypingHarness plan --corpus <path>... --output <path>
                               [--sentences <count>] [--noise <key pitches>] [--seed <value>]
      KeyVoxTypingHarness compare --plan <path> --apple <results-json>
                                  [--decider july|channel] [--disagreements <tsv-path>]
      KeyVoxTypingHarness tune --tune-plan <path>... [--holdout-plan <path>...] [--passes <count>]
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
                case "--decider": options.decider = try Self.decider(after: flag, in: &remaining)
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
                case "--decider": options.decider = try Self.decider(after: flag, in: &remaining)
                default: throw HarnessError.unknownFlag(flag)
                }
            }
            guard options.planPath.isEmpty == false, options.appleResultsPath.isEmpty == false else {
                throw HarnessError.usage
            }
            self = .compare(options)
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
        default:
            return false
        }
        return true
    }

    private static func decider(
        after flag: String,
        in remaining: inout ArraySlice<String>
    ) throws -> CorrectionEvaluator.Decider {
        switch try value(after: flag, in: &remaining) {
        case "july": return .july
        case "channel": return .channel(NoisyChannelCorrector.standardParameters)
        default: throw HarnessError.invalidValue(flag)
        }
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
            seed: seed
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
