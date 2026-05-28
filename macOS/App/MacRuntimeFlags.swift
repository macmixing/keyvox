import Foundation

enum MacRuntimeFlags {
    static let forceOnboardingEnvironmentKey = "KEYVOX_FORCE_ONBOARDING"
    static let forceFirstDictationOnboardingEnvironmentKey = "KEYVOX_FORCE_FIRST_DICTATION_ONBOARDING"
    static let forceMicPickerEnvironmentKey = "KEYVOX_FORCE_MIC_PICKER"
    static let modelDownloadPreviewErrorEnvironmentKey = "KVX_MODEL_DOWNLOAD_PREVIEW_ERROR"
    static let debugLogRawTextEnvironmentKey = "KVX_DEBUG_LOG_RAW_TEXT"
    static let forceKeyVoxVibesIntroEnvironmentKey = "KEYVOX_FORCE_KEYVOX_VIBES_INTRO"

    static var forceOnboarding: Bool {
        forceOnboarding(environment: ProcessInfo.processInfo.environment)
    }

    static var forceFirstDictationOnboarding: Bool {
        forceFirstDictationOnboarding(environment: ProcessInfo.processInfo.environment)
    }

    static var forceMicPicker: Bool {
#if DEBUG
        forceMicPicker(environment: ProcessInfo.processInfo.environment)
#else
        false
#endif
    }

    static var debugLogRawText: Bool {
        debugLogRawText(environment: ProcessInfo.processInfo.environment)
    }

    static func forceOnboarding(environment: [String: String]) -> Bool {
        isEnabled(environmentValue: environment[forceOnboardingEnvironmentKey])
    }

    static func forceFirstDictationOnboarding(environment: [String: String]) -> Bool {
        isEnabled(environmentValue: environment[forceFirstDictationOnboardingEnvironmentKey])
    }

    static func forceMicPicker(environment: [String: String]) -> Bool {
#if DEBUG
        isEnabled(environmentValue: environment[forceMicPickerEnvironmentKey])
#else
        false
#endif
    }

    static func modelDownloadPreviewErrorValue(environment: [String: String]) -> String? {
#if DEBUG
        normalizedValue(environment[modelDownloadPreviewErrorEnvironmentKey])
#else
        nil
#endif
    }

    static func debugLogRawText(environment: [String: String]) -> Bool {
        environment[debugLogRawTextEnvironmentKey] == "1"
    }

    static func forceKeyVoxVibesIntro(environment: [String: String]) -> Bool {
        isEnabled(environmentValue: environment[forceKeyVoxVibesIntroEnvironmentKey])
    }

    private static func isEnabled(environmentValue: String?) -> Bool {
        let normalizedValue = normalizedValue(environmentValue)

        return normalizedValue == "1"
            || normalizedValue == "true"
            || normalizedValue == "yes"
    }

    private static func normalizedValue(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
