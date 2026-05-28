import Foundation

enum MacRuntimeFlags {
    static let forceOnboardingEnvironmentKey = "KEYVOX_FORCE_ONBOARDING"
    static let forceFirstDictationOnboardingEnvironmentKey = "KEYVOX_FORCE_FIRST_DICTATION_ONBOARDING"

    static var forceOnboarding: Bool {
        isEnabled(environmentValue: ProcessInfo.processInfo.environment[forceOnboardingEnvironmentKey])
    }

    static var forceFirstDictationOnboarding: Bool {
        isEnabled(environmentValue: ProcessInfo.processInfo.environment[forceFirstDictationOnboardingEnvironmentKey])
    }

    private static func isEnabled(environmentValue: String?) -> Bool {
        let normalizedValue = environmentValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalizedValue == "1"
            || normalizedValue == "true"
            || normalizedValue == "yes"
    }
}
