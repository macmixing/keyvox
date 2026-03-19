import AVFoundation
import Testing
@testable import KeyVox_iOS

struct AudioInputPreferenceResolverTests {
    @Test func prefersBuiltInMicrophoneWhenEnabled() {
        let resolver = AudioInputPreferenceResolver()

        let action = resolver.resolve(
            availableInputs: [
                .init(id: "bluetooth", portType: .bluetoothHFP),
                .init(id: "built-in", portType: .builtInMic)
            ],
            preferBuiltInMicrophone: true
        )

        switch action {
        case .preferInput(let id):
            #expect(id == "built-in")
        case .useSystemDefault, .keepCurrentRoute:
            Issue.record("Expected built-in microphone to be preferred.")
        }
    }

    @Test func usesSystemDefaultWhenPreferenceDisabled() {
        let resolver = AudioInputPreferenceResolver()

        let action = resolver.resolve(
            availableInputs: [
                .init(id: "built-in", portType: .builtInMic)
            ],
            preferBuiltInMicrophone: false
        )

        switch action {
        case .useSystemDefault:
            break
        case .preferInput, .keepCurrentRoute:
            Issue.record("Expected the system default route to be used.")
        }
    }

    @Test func keepsCurrentRouteWhenBuiltInMicrophoneIsUnavailable() {
        let resolver = AudioInputPreferenceResolver()

        let action = resolver.resolve(
            availableInputs: [
                .init(id: "bluetooth", portType: .bluetoothHFP)
            ],
            preferBuiltInMicrophone: true
        )

        switch action {
        case .keepCurrentRoute:
            break
        case .preferInput, .useSystemDefault:
            Issue.record("Expected the current route to be preserved.")
        }
    }
}
