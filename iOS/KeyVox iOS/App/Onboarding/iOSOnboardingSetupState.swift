import Foundation

struct iOSOnboardingSetupState: Equatable {
    let isModelReady: Bool
    let isMicrophonePermissionGranted: Bool
    let isKeyboardAccessConfirmed: Bool

    var canContinue: Bool {
        isModelReady && isMicrophonePermissionGranted && isKeyboardAccessConfirmed
    }
}
