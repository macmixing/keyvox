import AVFoundation
import Foundation

/// Picks the microphone the capture page asks for, honoring the containing app's Prefer Built-In
/// Microphone setting. A capture page learns its microphones' IDs only once it has recorded, and
/// the keyboard builds a fresh page each time it appears, so the built-in microphone's ID is kept
/// from earlier recordings; WebKit gives the same microphone the same ID on every page.
final class KeyboardMicrophoneSelection {
    struct Microphone: Equatable {
        let label: String
        let id: String
    }

    private static let builtInMicrophoneIDKey = "KeyboardMicrophoneSelection.builtInMicrophoneID"

    private let prefersBuiltInMicrophone: () -> Bool
    private let builtInMicrophoneName: () -> String?
    private let defaults: UserDefaults

    init(
        prefersBuiltInMicrophone: @escaping () -> Bool,
        builtInMicrophoneName: @escaping () -> String? = {
            AVAudioSession.sharedInstance().availableInputs?
                .first { $0.portType == .builtInMic }?
                .portName
        },
        defaults: UserDefaults = .standard
    ) {
        self.prefersBuiltInMicrophone = prefersBuiltInMicrophone
        self.builtInMicrophoneName = builtInMicrophoneName
        self.defaults = defaults
    }

    /// The page's ID for the microphone to ask for, or nil to use the microphone WebKit picks.
    var preferredMicrophoneID: String? {
        guard prefersBuiltInMicrophone() else { return nil }
        return defaults.string(forKey: Self.builtInMicrophoneIDKey)
    }

    /// Keeps the built-in microphone's ID from the microphones a page that has recorded lists.
    func remember(_ microphones: [Microphone]) {
        guard let name = builtInMicrophoneName(),
              let builtIn = microphones.first(where: { $0.label == name && !$0.id.isEmpty }) else {
            return
        }
        defaults.set(builtIn.id, forKey: Self.builtInMicrophoneIDKey)
    }
}
