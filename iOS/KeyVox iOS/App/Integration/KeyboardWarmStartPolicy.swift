import Foundation

/// Decides whether the keyboard may start dictation without opening the app.
/// A dictation start that needs a new Live Activity can only succeed while the app is active,
/// so a backgrounded app without a running session must not advertise itself as warm.
enum KeyboardWarmStartPolicy {
    static func isWarmStartAvailable(
        isAppActive: Bool,
        isDictationSessionActive: Bool,
        isDictationInProgress: Bool,
        isTTSActive: Bool,
        liveActivitiesEnabled: Bool
    ) -> Bool {
        isAppActive
            || isDictationSessionActive
            || isDictationInProgress
            || isTTSActive
            || !liveActivitiesEnabled
    }
}
