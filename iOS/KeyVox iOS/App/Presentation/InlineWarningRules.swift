import Foundation

enum InlineWarningRules {
    static func showsOnboardingCellularModelWarning(
        isOnCellular: Bool,
        modelState: ModelInstallState
    ) -> Bool {
        isOnCellular && modelState == .notInstalled
    }

    static func showsKeyVoxSpeakSetupWarning(
        isOnCellular: Bool,
        sharedModelState: PocketTTSInstallState,
        voiceState: PocketTTSInstallState
    ) -> Bool {
        guard isOnCellular else { return false }

        if case .ready = sharedModelState,
           case .ready = voiceState {
            return false
        }

        return true
    }

    static func showsHomeTTSCellularDownloadWarning(
        isOnCellular: Bool,
        sharedModelState: PocketTTSInstallState
    ) -> Bool {
        guard isOnCellular else { return false }
        return sharedModelState == .notInstalled
    }

    static func showsSettingsCombinedTextModelWarning(
        isOnCellular: Bool,
        modelStates: [ModelInstallState]
    ) -> Bool {
        guard isOnCellular else { return false }
        return modelStates.isEmpty == false && modelStates.allSatisfy { $0 == .notInstalled }
    }

    static func showsSettingsIndividualTextModelWarning(
        isOnCellular: Bool,
        showsCombinedWarning: Bool,
        modelState: ModelInstallState
    ) -> Bool {
        guard showsCombinedWarning == false else { return false }
        guard isOnCellular else { return false }
        return modelState == .notInstalled
    }

    static func showsSettingsTTSCellularDownloadWarning(
        isOnCellular: Bool,
        sharedModelState: PocketTTSInstallState
    ) -> Bool {
        guard isOnCellular else { return false }
        return sharedModelState == .notInstalled
    }
}
