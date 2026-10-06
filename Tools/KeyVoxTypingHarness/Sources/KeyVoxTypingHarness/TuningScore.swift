/// How a set of corrector parameters did across tuning samples.
struct TuningScore {
    /// Each correctly typed word that space breaks counts this many extra misses.
    static let brokenWordWeight = 1.0

    private(set) var total = 0
    private(set) var correct = 0
    private(set) var needingCorrection = 0
    private(set) var fixed = 0
    private(set) var typedCorrectly = 0
    private(set) var broken = 0

    mutating func record(intended: String, typed: String, final: String) {
        total += 1
        let isCorrect = final == intended
        correct += isCorrect ? 1 : 0
        if typed == intended {
            typedCorrectly += 1
            broken += isCorrect ? 0 : 1
        } else {
            needingCorrection += 1
            fixed += isCorrect ? 1 : 0
        }
    }

    var objective: Double {
        guard total > 0 else { return 0 }
        return (Double(correct) - Self.brokenWordWeight * Double(broken)) / Double(total)
    }

    var summary: String {
        func percent(_ count: Int, _ of: Int) -> String {
            String(format: "%.2f%%", EvaluationReport.rate(count, of: of) * 100)
        }
        return "final correct \(percent(correct, total))"
            + "  fixed \(percent(fixed, needingCorrection)) of \(needingCorrection)"
            + "  broken \(percent(broken, typedCorrectly)) (\(broken))"
    }
}
