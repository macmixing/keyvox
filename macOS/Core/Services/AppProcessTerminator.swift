import Darwin
import Foundation

enum AppProcessTerminator {
    @MainActor
    static func terminateImmediately() -> Never {
        fflush(nil)
        UserDefaults.standard.synchronize()
        Darwin._exit(EXIT_SUCCESS)
    }
}
