import Testing
@testable import KeyVox_iOS

struct InlineWarningRulesTests {
    @Test func onboardingSetupWarningShowsOnlyForCellularAndMissingModel() {
        #expect(
            InlineWarningRules.showsOnboardingCellularModelWarning(
                isOnCellular: true,
                modelState: .notInstalled
            )
        )
        #expect(
            InlineWarningRules.showsOnboardingCellularModelWarning(
                isOnCellular: false,
                modelState: .notInstalled
            ) == false
        )
        #expect(
            InlineWarningRules.showsOnboardingCellularModelWarning(
                isOnCellular: true,
                modelState: .ready
            ) == false
        )
    }

    @Test func keyVoxSpeakSetupWarningShowsOnCellularUntilSharedModelAndVoiceAreReady() {
        #expect(
            InlineWarningRules.showsKeyVoxSpeakSetupWarning(
                isOnCellular: true,
                sharedModelState: .notInstalled,
                voiceState: .notInstalled
            )
        )
        #expect(
            InlineWarningRules.showsKeyVoxSpeakSetupWarning(
                isOnCellular: true,
                sharedModelState: .ready,
                voiceState: .notInstalled
            )
        )
        #expect(
            InlineWarningRules.showsKeyVoxSpeakSetupWarning(
                isOnCellular: true,
                sharedModelState: .ready,
                voiceState: .ready
            ) == false
        )
        #expect(
            InlineWarningRules.showsKeyVoxSpeakSetupWarning(
                isOnCellular: false,
                sharedModelState: .notInstalled,
                voiceState: .notInstalled
            ) == false
        )
    }

    @Test func homeTTSWarningShowsOnlyForCellularAndMissingSharedModel() {
        #expect(
            InlineWarningRules.showsHomeTTSCellularDownloadWarning(
                isOnCellular: true,
                sharedModelState: .notInstalled
            )
        )
        #expect(
            InlineWarningRules.showsHomeTTSCellularDownloadWarning(
                isOnCellular: true,
                sharedModelState: .ready
            ) == false
        )
        #expect(
            InlineWarningRules.showsHomeTTSCellularDownloadWarning(
                isOnCellular: false,
                sharedModelState: .notInstalled
            ) == false
        )
    }

    @Test func settingsCombinedTextModelWarningShowsOnlyWhenEveryModelIsMissingOnCellular() {
        #expect(
            InlineWarningRules.showsSettingsCombinedTextModelWarning(
                isOnCellular: true,
                modelStates: [.notInstalled, .notInstalled]
            )
        )
        #expect(
            InlineWarningRules.showsSettingsCombinedTextModelWarning(
                isOnCellular: true,
                modelStates: [.notInstalled, .ready]
            ) == false
        )
        #expect(
            InlineWarningRules.showsSettingsCombinedTextModelWarning(
                isOnCellular: false,
                modelStates: [.notInstalled, .notInstalled]
            ) == false
        )
    }

    @Test func settingsIndividualTextModelWarningShowsOnlyForCellularMissingModelWithoutCombinedWarning() {
        #expect(
            InlineWarningRules.showsSettingsIndividualTextModelWarning(
                isOnCellular: true,
                showsCombinedWarning: false,
                modelState: .notInstalled
            )
        )
        #expect(
            InlineWarningRules.showsSettingsIndividualTextModelWarning(
                isOnCellular: true,
                showsCombinedWarning: true,
                modelState: .notInstalled
            ) == false
        )
        #expect(
            InlineWarningRules.showsSettingsIndividualTextModelWarning(
                isOnCellular: true,
                showsCombinedWarning: false,
                modelState: .ready
            ) == false
        )
        #expect(
            InlineWarningRules.showsSettingsIndividualTextModelWarning(
                isOnCellular: false,
                showsCombinedWarning: false,
                modelState: .notInstalled
            ) == false
        )
    }

    @Test func settingsTTSWarningShowsOnlyForCellularAndMissingSharedModel() {
        #expect(
            InlineWarningRules.showsSettingsTTSCellularDownloadWarning(
                isOnCellular: true,
                sharedModelState: .notInstalled
            )
        )
        #expect(
            InlineWarningRules.showsSettingsTTSCellularDownloadWarning(
                isOnCellular: true,
                sharedModelState: .ready
            ) == false
        )
        #expect(
            InlineWarningRules.showsSettingsTTSCellularDownloadWarning(
                isOnCellular: false,
                sharedModelState: .notInstalled
            ) == false
        )
    }
}
