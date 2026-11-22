import Foundation
import Testing
@testable import KeyVox_iOS

struct KeyboardMicrophoneSelectionTests {
    @Test func asksForTheRememberedBuiltInMicrophoneWhenTheSettingIsOn() {
        withDefaults { defaults in
            let builtIn = KeyboardMicrophoneSelection.Microphone(label: "Built-In", id: "built-in-id")
            let other = KeyboardMicrophoneSelection.Microphone(label: "Headset", id: "headset-id")
            let selection = KeyboardMicrophoneSelection(
                prefersBuiltInMicrophone: { true },
                builtInMicrophoneName: { builtIn.label },
                defaults: defaults
            )

            #expect(selection.preferredMicrophoneID == nil)

            selection.remember([other, builtIn])

            #expect(selection.preferredMicrophoneID == builtIn.id)
        }
    }

    @Test func leavesTheChoiceToWebKitWhenTheSettingIsOff() {
        withDefaults { defaults in
            let builtIn = KeyboardMicrophoneSelection.Microphone(label: "Built-In", id: "built-in-id")
            let selection = KeyboardMicrophoneSelection(
                prefersBuiltInMicrophone: { false },
                builtInMicrophoneName: { builtIn.label },
                defaults: defaults
            )

            selection.remember([builtIn])

            #expect(selection.preferredMicrophoneID == nil)
        }
    }

    @Test func keepsTheRememberedMicrophoneWhenAPageListsNoIDs() {
        withDefaults { defaults in
            let builtIn = KeyboardMicrophoneSelection.Microphone(label: "Built-In", id: "built-in-id")
            let selection = KeyboardMicrophoneSelection(
                prefersBuiltInMicrophone: { true },
                builtInMicrophoneName: { builtIn.label },
                defaults: defaults
            )

            selection.remember([builtIn])
            selection.remember([KeyboardMicrophoneSelection.Microphone(label: "", id: "")])

            #expect(selection.preferredMicrophoneID == builtIn.id)
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "KeyboardMicrophoneSelectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
