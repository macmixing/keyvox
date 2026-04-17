import Foundation

struct OnboardingKeyboardTourHandoffState: Equatable {
    let isModelReady: Bool
    let isMicrophonePermissionGranted: Bool
    let isKeyboardEnabledInSystemSettings: Bool

    var canStartKeyboardTour: Bool {
        isModelReady && isMicrophonePermissionGranted && isKeyboardEnabledInSystemSettings
    }
}
