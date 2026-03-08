import Foundation

/// Centralized UserDefaults key definitions for the entire app.
/// All keys are namespaced under `KeyVox.` to avoid collisions.
enum UserDefaultsKeys {
    static let hasCompletedOnboarding = "KeyVox.HasCompletedOnboarding"
    static let triggerBinding         = "KeyVox.TriggerBinding"
    static let autoParagraphsEnabled  = "KeyVox.AutoParagraphsEnabled"
    static let listFormattingEnabled  = "KeyVox.ListFormattingEnabled"
    static let isSoundEnabled         = "KeyVox.IsSoundEnabled"
    static let soundVolume            = "KeyVox.SoundVolume"
    static let selectedMicrophoneUID  = "KeyVox.SelectedMicrophoneUID"
    static let hasInitializedMicrophoneDefault = "KeyVox.HasInitializedMicrophoneDefault"
    static let recordingOverlayOrigin = "KeyVox.RecordingOverlayOrigin"
    static let recordingOverlayPreferredDisplayKey = "KeyVox.RecordingOverlayPreferredDisplayKey"
    static let recordingOverlayOriginsByDisplay = "KeyVox.RecordingOverlayOriginsByDisplay"

    enum App {
        static let updateAlertLastShown = "KeyVox.App.UpdateAlertLastShown"
        static let updateAlertSnoozedUntil = "KeyVox.App.UpdateAlertSnoozedUntil"
        static let wordsThisWeekCount = "KeyVox.App.WordsThisWeekCount"
        static let wordsThisWeekWeekStart = "KeyVox.App.WordsThisWeekWeekStart"
    }

    enum iCloud {
        static let dictionaryLastModifiedAt = "KeyVox.iCloud.DictionaryLastModifiedAt"
        static let autoParagraphsLastModifiedAt = "KeyVox.iCloud.AutoParagraphsLastModifiedAt"
        static let listFormattingLastModifiedAt = "KeyVox.iCloud.ListFormattingLastModifiedAt"
    }
}
