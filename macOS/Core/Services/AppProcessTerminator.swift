import Darwin

enum AppProcessTerminator {
    @MainActor
    static func terminateImmediately() -> Never {
        fflush(nil)
        Darwin._exit(EXIT_SUCCESS)
    }
}
