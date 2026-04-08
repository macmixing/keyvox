import Foundation

struct RuntimeFlags {
    static let forceOnboardingEnvironmentKey = "KEYVOX_FORCE_ONBOARDING"
    static let bypassTTSFreeSpeakLimitEnvironmentKey = "KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT"
    static let forceKeyVoxSpeakIntroEnvironmentKey = "KEYVOX_FORCE_KEYVOX_SPEAK_INTRO"
    static let forceTTSRegenerationEnvironmentKey = "KEYVOX_FORCE_TTS_REGENERATION"

    let forceOnboarding: Bool
    let bypassTTSFreeSpeakLimit: Bool
    let forceKeyVoxSpeakIntro: Bool
    let forceTTSRegeneration: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        forceOnboarding = Self.isEnabled(
            environmentValue: environment[Self.forceOnboardingEnvironmentKey]
        )
        bypassTTSFreeSpeakLimit = Self.isEnabled(
            environmentValue: environment[Self.bypassTTSFreeSpeakLimitEnvironmentKey]
        )
        forceKeyVoxSpeakIntro = Self.isEnabled(
            environmentValue: environment[Self.forceKeyVoxSpeakIntroEnvironmentKey]
        )
        forceTTSRegeneration = Self.isEnabled(
            environmentValue: environment[Self.forceTTSRegenerationEnvironmentKey]
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
