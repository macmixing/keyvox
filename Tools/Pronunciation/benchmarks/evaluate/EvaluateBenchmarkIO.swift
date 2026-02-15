import Foundation

struct PositiveCase {
    let observed: String
    let expected: String
}

struct QualityMetrics {
    let coverage: Double
    let hitRate: Double
    let falsePositiveRate: Double
    let medianLatencyMS: Double
}

func loadLines(at path: String) throws -> [String] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    return content
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

func loadLexicon(at path: String) throws -> [String: String] {
    var map: [String: String] = [:]
    for line in try loadLines(at: path) {
        let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        let word = TextNormalization.normalizedToken(String(parts[0]))
        let signature = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !signature.isEmpty else { continue }
        map[word] = signature
    }
    return map
}

func loadPositiveCases(at path: String) throws -> [PositiveCase] {
    var cases: [PositiveCase] = []
    for line in try loadLines(at: path) {
        let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        cases.append(PositiveCase(observed: String(parts[0]), expected: String(parts[1])))
    }
    return cases
}

func parseRepoRoot(from arguments: [String]) -> String {
    if let index = arguments.firstIndex(of: "--repo-root"), index + 1 < arguments.count {
        return arguments[index + 1]
    }
    return FileManager.default.currentDirectoryPath
}

func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
    return sorted[mid]
}
