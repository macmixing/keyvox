import Foundation

nonisolated enum UserDefaultsKeys {
    static let triggerBinding = "KeyVox.TriggerBinding"
    static let autoParagraphsEnabled = "KeyVox.AutoParagraphsEnabled"
    static let listFormattingEnabled = "KeyVox.ListFormattingEnabled"
    static let capsLockEnabled = "KeyVox.CapsLockEnabled"
    static let keyboardHapticsEnabled = "KeyVox.KeyboardHapticsEnabled"
    static let preferBuiltInMicrophone = "KeyVox.PreferBuiltInMicrophone"
    static let liveActivitiesEnabled = "KeyVox.LiveActivitiesEnabled"
    static let sessionDisableTiming = "KeyVox.SessionDisableTiming"

    enum App {
        static let weeklyWordStatsPayload = "KeyVox.App.WeeklyWordStatsPayload"
        static let weeklyWordStatsInstallationID = "KeyVox.App.WeeklyWordStatsInstallationID"
        static let hasCompletedOnboarding = "KeyVox.App.HasCompletedOnboarding"
        static let hasCompletedOnboardingWelcome = "KeyVox.App.HasCompletedOnboardingWelcome"
        static let hasPendingKeyboardTour = "KeyVox.App.HasPendingKeyboardTour"
    }

    enum iCloud {
        static let dictionaryLastModifiedAt = "KeyVox.iCloud.DictionaryLastModifiedAt"
        static let triggerBindingLastModifiedAt = "KeyVox.iCloud.TriggerBindingLastModifiedAt"
        static let autoParagraphsLastModifiedAt = "KeyVox.iCloud.AutoParagraphsLastModifiedAt"
        static let listFormattingLastModifiedAt = "KeyVox.iCloud.ListFormattingLastModifiedAt"
    }
}
