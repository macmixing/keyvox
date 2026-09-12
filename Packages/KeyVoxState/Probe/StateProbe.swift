// Supplies the executor linkage for the statically linked Android probe.
import Dispatch
import StateVerification

@main
struct StateProbe {
    static func main() async throws {
        try await StateVerification.verify()
        print("State publication checks passed")
    }
}
