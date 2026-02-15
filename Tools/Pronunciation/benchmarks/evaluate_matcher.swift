import Darwin
import Foundation

@main
struct EvaluateMatcherEntrypoint {
    static func main() {
        exit(
            runEvaluateMatcherMain(
                arguments: CommandLine.arguments,
                environment: ProcessInfo.processInfo.environment
            )
        )
    }
}
