import Foundation

struct RuntimeFlags {
    static let forceOnboardingEnvironmentKey = "KEYVOX_FORCE_ONBOARDING"
    static let bypassTTSFreeSpeakLimitEnvironmentKey = "KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT"
    static let forceKeyVoxSpeakIntroEnvironmentKey = "KEYVOX_FORCE_KEYVOX_SPEAK_INTRO"
    static let bypassVibesTrialEnvironmentKey = "KEYVOX_BYPASS_VIBES_TRIAL"
    static let vibesTrialDurationSecondsEnvironmentKey = "KEYVOX_VIBES_TRIAL_DURATION_SECONDS"
    static let resetVibesTrialEnvironmentKey = "KEYVOX_RESET_VIBES_TRIAL"
    static let forceKeyVoxVibesIntroEnvironmentKey = "KEYVOX_FORCE_KEYVOX_VIBES_INTRO"
    static let forceTTSRegenerationEnvironmentKey = "KEYVOX_FORCE_TTS_REGENERATION"

    let forceOnboarding: Bool
    let bypassTTSFreeSpeakLimit: Bool
    let forceKeyVoxSpeakIntro: Bool
    let bypassVibesTrial: Bool
    let vibesTrialDurationOverride: TimeInterval?
    let resetVibesTrial: Bool
    let forceKeyVoxVibesIntro: Bool
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
        bypassVibesTrial = Self.isEnabled(
            environmentValue: environment[Self.bypassVibesTrialEnvironmentKey]
        )
        vibesTrialDurationOverride = Self.positiveTimeInterval(
            environmentValue: environment[Self.vibesTrialDurationSecondsEnvironmentKey]
        )
        resetVibesTrial = Self.isEnabled(
            environmentValue: environment[Self.resetVibesTrialEnvironmentKey]
        )
        forceKeyVoxVibesIntro = Self.isEnabled(
            environmentValue: environment[Self.forceKeyVoxVibesIntroEnvironmentKey]
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

    private static func positiveTimeInterval(environmentValue: String?) -> TimeInterval? {
        guard let environmentValue else { return nil }
        let trimmedValue = environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = TimeInterval(trimmedValue), seconds > 0 else { return nil }

        #if DEBUG
        return seconds
        #else
        return nil
        #endif
    }
}
