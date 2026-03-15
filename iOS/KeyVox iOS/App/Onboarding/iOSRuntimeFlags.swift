import Foundation

struct iOSRuntimeFlags {
    static let forceOnboardingEnvironmentKey = "KEYVOX_FORCE_ONBOARDING"

    let forceOnboarding: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let normalizedValue = environment[Self.forceOnboardingEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        forceOnboarding = normalizedValue == "1"
            || normalizedValue == "true"
            || normalizedValue == "yes"
    }
}
