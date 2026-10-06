import Foundation

struct HarnessOptions {
    var corpusPaths: [String] = []
    var sentenceLimit = 400
    var noiseStandardDeviation = 6.0
    var seed: UInt64 = 1
    var usesTouches = true
    var failuresPath: String?

    static let usage = """
    usage: KeyVoxTypingHarness evaluate --corpus <path> [--corpus <path> ...]
                                        [--sentences <count>] [--noise <points>]
                                        [--seed <value>] [--no-touches]
                                        [--failures <tsv-path>]
    """

    init(arguments: [String]) throws {
        guard arguments.first == "evaluate" else { throw HarnessError.usage }
        var remaining = arguments.dropFirst()
        while let flag = remaining.popFirst() {
            switch flag {
            case "--corpus":
                corpusPaths.append(try Self.value(after: flag, in: &remaining))
            case "--sentences":
                sentenceLimit = try Self.integer(after: flag, in: &remaining)
            case "--noise":
                guard let value = Double(try Self.value(after: flag, in: &remaining)),
                      value >= 0 else {
                    throw HarnessError.invalidValue(flag)
                }
                noiseStandardDeviation = value
            case "--seed":
                guard let value = UInt64(try Self.value(after: flag, in: &remaining)) else {
                    throw HarnessError.invalidValue(flag)
                }
                seed = value
            case "--no-touches":
                usesTouches = false
            case "--failures":
                failuresPath = try Self.value(after: flag, in: &remaining)
            default:
                throw HarnessError.unknownFlag(flag)
            }
        }
        guard corpusPaths.isEmpty == false else { throw HarnessError.usage }
    }

    private static func value(
        after flag: String,
        in remaining: inout ArraySlice<String>
    ) throws -> String {
        guard let value = remaining.popFirst() else { throw HarnessError.invalidValue(flag) }
        return value
    }

    private static func integer(
        after flag: String,
        in remaining: inout ArraySlice<String>
    ) throws -> Int {
        guard let value = Int(try value(after: flag, in: &remaining)), value > 0 else {
            throw HarnessError.invalidValue(flag)
        }
        return value
    }
}

enum HarnessError: Error, CustomStringConvertible {
    case usage
    case unknownFlag(String)
    case invalidValue(String)
    case unreadableCorpus(String)

    var description: String {
        switch self {
        case .usage:
            return HarnessOptions.usage
        case .unknownFlag(let flag):
            return "unknown flag \(flag)\n\(HarnessOptions.usage)"
        case .invalidValue(let flag):
            return "missing or invalid value for \(flag)"
        case .unreadableCorpus(let path):
            return "could not read corpus at \(path)"
        }
    }
}
