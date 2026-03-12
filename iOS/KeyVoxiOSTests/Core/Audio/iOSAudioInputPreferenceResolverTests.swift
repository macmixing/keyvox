import AVFoundation
import Testing
@testable import KeyVox_iOS

struct iOSAudioInputPreferenceResolverTests {
    @Test func prefersBuiltInMicrophoneWhenEnabled() {
        let resolver = iOSAudioInputPreferenceResolver()

        let action = resolver.resolve(
            availableInputs: [
                .init(id: "bluetooth", portType: .bluetoothHFP),
                .init(id: "built-in", portType: .builtInMic)
            ],
            preferBuiltInMicrophone: true
        )

        #expect(action == .preferInput(id: "built-in"))
    }

    @Test func usesSystemDefaultWhenPreferenceDisabled() {
        let resolver = iOSAudioInputPreferenceResolver()

        let action = resolver.resolve(
            availableInputs: [
                .init(id: "built-in", portType: .builtInMic)
            ],
            preferBuiltInMicrophone: false
        )

        #expect(action == .useSystemDefault)
    }

    @Test func keepsCurrentRouteWhenBuiltInMicrophoneIsUnavailable() {
        let resolver = iOSAudioInputPreferenceResolver()

        let action = resolver.resolve(
            availableInputs: [
                .init(id: "bluetooth", portType: .bluetoothHFP)
            ],
            preferBuiltInMicrophone: true
        )

        #expect(action == .keepCurrentRoute)
    }
}
