import Foundation

/// Centralized UserDefaults key definitions for the entire app.
/// All keys are namespaced under `KeyVox.` to avoid collisions.
enum UserDefaultsKeys {
    static let hasCompletedOnboarding = "KeyVox.HasCompletedOnboarding"
    static let triggerBinding         = "KeyVox.TriggerBinding"
    static let isSoundEnabled         = "KeyVox.IsSoundEnabled"
}
