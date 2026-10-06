import Foundation

@main
struct TypingHarness {
    static func main() {
        do {
            switch try HarnessCommand(arguments: Array(CommandLine.arguments.dropFirst())) {
            case .evaluate(let options):
                try EvaluateCommand.run(options)
            case .plan(let options):
                try PlanCommand.run(options)
            case .compare(let options):
                try CompareCommand.run(options)
            case .tune(let options):
                try TuneCommand.run(options)
            case .explain(let options):
                try ExplainCommand.run(options)
            }
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }
}
