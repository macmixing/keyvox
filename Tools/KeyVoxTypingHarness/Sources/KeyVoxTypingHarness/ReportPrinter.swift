import Foundation

/// Renders an evaluation report as plain text for the terminal.
enum ReportPrinter {
    static func render(_ report: EvaluationReport, options: HarnessOptions) -> String {
        let exact = report.corrections(of: .exact)
        let apostrophe = report.corrections(of: .missingApostrophe)
        let mistyped = report.corrections(of: .mistyped)
        let mistypedFixed = mistyped.filter(\.isFinalWordCorrect)
        let mistypedChangedWrongly = mistyped.filter {
            $0.correction != nil && $0.isFinalWordCorrect == false
        }
        let mistypedUntouched = mistyped.filter { $0.correction == nil }
        let realWordErrors = mistyped.filter(\.typedWordIsValid)
        let exactBroken = exact.filter { $0.isFinalWordCorrect == false }

        var lines = [
            "Typing evaluation",
            "  sentences: \(report.sentenceCount)   words: \(report.corrections.count)",
            "  touch noise: \(options.noiseStandardDeviation) pt standard deviation"
                + "   touches sent to engine: \(options.usesTouches ? "yes" : "no")",
            "",
            "Final words after space",
            "  correct with autocorrect:    \(percent(report.finalWordAccuracy))",
            "  correct with autocorrect off: \(percent(report.uncorrectedWordAccuracy))",
            "",
            "Mistyped words: \(mistyped.count)",
            "  fixed to the intended word:   \(share(mistypedFixed.count, of: mistyped.count))",
            "  changed to a different word:  \(share(mistypedChangedWrongly.count, of: mistyped.count))",
            "  left as typed:                \(share(mistypedUntouched.count, of: mistyped.count))",
            "  typo is itself a real word:   \(share(realWordErrors.count, of: mistyped.count))",
            "  intended word ranked #1:      \(rankShare(mistyped, 1...1))",
            "  intended word ranked #2-3:    \(rankShare(mistyped, 2...3))",
            "  intended word ranked #4-8:    \(rankShare(mistyped, 4...8))",
            "  intended word not offered:    \(share(mistyped.filter { $0.intendedRank == nil }.count, of: mistyped.count))",
            "",
            "Contractions typed without the apostrophe: \(apostrophe.count)",
            "  apostrophe restored:          \(share(apostrophe.filter(\.isFinalWordCorrect).count, of: apostrophe.count))",
            "",
            "Correctly typed words: \(exact.count)",
            "  wrongly changed:              \(share(exactBroken.count, of: exact.count))",
            "",
            "Completions (top \(CompletionEvaluator.visibleCompletionCount), clean typing): \(report.completions.count) words",
            "  offered after 1 letter:       \(percent(report.completionOfferRate(withinLetters: 1)))",
            "  offered within 2 letters:     \(percent(report.completionOfferRate(withinLetters: 2)))",
            "  offered within 3 letters:     \(percent(report.completionOfferRate(withinLetters: 3)))",
            "  keystroke savings:            \(percent(report.completionKeystrokeSavings))",
            "",
            "Next-word predictions: \(report.nextWords.count) words",
            "  intended word first:          \(percent(report.nextWordRate(withinRank: 1)))",
            "  intended word in top 3:       \(percent(report.nextWordRate(withinRank: 3)))",
            "",
            "Speed (this Mac)",
            "  engine startup:               \(milliseconds(report.engineStartupMilliseconds))",
            "  correction call median:       \(milliseconds(report.correctionLatency(percentile: 0.5)))",
            "  correction call 95th pct:     \(milliseconds(report.correctionLatency(percentile: 0.95)))",
        ]
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Tab-separated rows for every word whose final form is wrong.
    static func failureRows(_ report: EvaluationReport) -> String {
        let header = "kind\tintended\ttyped\tfinal\treason\tintended_rank\taction_probability\tprevious\tsuggestions"
        let rows = report.corrections
            .filter { $0.isFinalWordCorrect == false }
            .map { outcome in
                [
                    String(describing: outcome.typingKind),
                    outcome.intendedWord,
                    outcome.typedWord,
                    outcome.finalWord,
                    outcome.reason,
                    outcome.intendedRank.map(String.init) ?? "-",
                    String(format: "%.4f", outcome.automaticCorrectionProbability),
                    outcome.previousWords.reversed().joined(separator: " "),
                    outcome.suggestions.joined(separator: ","),
                ].joined(separator: "\t")
            }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func rankShare(_ outcomes: [CorrectionOutcome], _ ranks: ClosedRange<Int>) -> String {
        share(outcomes.filter { $0.intendedRank.map(ranks.contains) == true }.count, of: outcomes.count)
    }

    private static func share(_ count: Int, of total: Int) -> String {
        "\(percent(EvaluationReport.rate(count, of: total)))  (\(count)/\(total))"
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func milliseconds(_ value: Double) -> String {
        String(format: "%.2f ms", value)
    }
}
