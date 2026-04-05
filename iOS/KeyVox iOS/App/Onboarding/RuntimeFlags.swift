import Foundation

struct RuntimeFlags {
    static let forceOnboardingEnvironmentKey = "KEYVOX_FORCE_ONBOARDING"
    static let bypassTTSFreeSpeakLimitEnvironmentKey = "KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT"

    let forceOnboarding: Bool
    let bypassTTSFreeSpeakLimit: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        forceOnboarding = Self.isEnabled(
            environmentValue: environment[Self.forceOnboardingEnvironmentKey]
        )
        bypassTTSFreeSpeakLimit = Self.isEnabled(
            environmentValue: environment[Self.bypassTTSFreeSpeakLimitEnvironmentKey]
        )
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
