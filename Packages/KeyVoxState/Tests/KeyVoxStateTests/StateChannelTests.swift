import Testing
import StateVerification

@Test func statePublication() async throws {
    try await StateVerification.verify()
}
