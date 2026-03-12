import Foundation

nonisolated enum iOSUserDefaultsKeys {
    static let triggerBinding = "KeyVox.TriggerBinding"
    static let autoParagraphsEnabled = "KeyVox.AutoParagraphsEnabled"
    static let listFormattingEnabled = "KeyVox.ListFormattingEnabled"
    static let capsLockEnabled = "KeyVox.CapsLockEnabled"
    static let preferBuiltInMicrophone = "KeyVox.PreferBuiltInMicrophone"
    static let sessionDisableTiming = "KeyVox.SessionDisableTiming"

    enum App {
        static let weeklyWordStatsPayload = "KeyVox.App.WeeklyWordStatsPayload"
        static let weeklyWordStatsInstallationID = "KeyVox.App.WeeklyWordStatsInstallationID"
    }

    enum iCloud {
        static let dictionaryLastModifiedAt = "KeyVox.iCloud.DictionaryLastModifiedAt"
        static let triggerBindingLastModifiedAt = "KeyVox.iCloud.TriggerBindingLastModifiedAt"
        static let autoParagraphsLastModifiedAt = "KeyVox.iCloud.AutoParagraphsLastModifiedAt"
        static let listFormattingLastModifiedAt = "KeyVox.iCloud.ListFormattingLastModifiedAt"
    }
}
