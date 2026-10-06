/// `plan`: writes a reproducible typing plan for the Apple keyboard baseline runner.
enum PlanCommand {
    static func run(_ options: HarnessCommand.PlanOptions) throws {
        let plan = try options.source.resolvePlan()
        try plan.write(to: options.outputPath)
        let wordCount = plan.sentences.reduce(0) { $0 + $1.words.count }
        print("Wrote \(plan.sentences.count) sentences (\(wordCount) words) to \(options.outputPath)")
    }
}
