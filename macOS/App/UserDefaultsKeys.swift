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
    static let selectedVibe           = "KeyVox.SelectedVibe"
    static let vibesTriggerKeyInteractionsEnabled = "KeyVox.VibesTriggerKeyInteractionsEnabled"
    static let hideDockIconWhenAllWindowsClosed = "KeyVox.HideDockIconWhenAllWindowsClosed"
    static let hasInitializedMicrophoneDefault = "KeyVox.HasInitializedMicrophoneDefault"
    static let recordingOverlayOrigin = "KeyVox.RecordingOverlayOrigin"
    static let recordingOverlayPreferredDisplayKey = "KeyVox.RecordingOverlayPreferredDisplayKey"
    static let recordingOverlayOriginsByDisplay = "KeyVox.RecordingOverlayOriginsByDisplay"

    enum App {
        static let updateAlertLastShown = "KeyVox.App.UpdateAlertLastShown"
        static let updateAlertSnoozedUntil = "KeyVox.App.UpdateAlertSnoozedUntil"
        static let pendingUpdatedVersion = "KeyVox.App.PendingUpdatedVersion"
        static let pendingUpdatedVersionPreferredDisplayKey = "KeyVox.App.PendingUpdatedVersionPreferredDisplayKey"
        static let lastAcknowledgedUpdatedVersion = "KeyVox.App.LastAcknowledgedUpdatedVersion"
        static let resumeUpdaterAfterApplicationsMove = "KeyVox.App.ResumeUpdaterAfterApplicationsMove"
        static let resumeUpdaterPreferredDisplayKey = "KeyVox.App.ResumeUpdaterPreferredDisplayKey"
        static let weeklyWordStatsPayload = "KeyVox.App.WeeklyWordStatsPayload"
        static let weeklyWordStatsInstallationID = "KeyVox.App.WeeklyWordStatsInstallationID"
        static let lastTranscription = "KeyVox.App.LastTranscription"
        static let activeDictationProvider = "KeyVox.App.ActiveDictationProvider"
        static let whisperDictationLanguage = "KeyVox.App.WhisperDictationLanguage"
        static let hasSeenKeyVoxVibesIntro = "KeyVox.App.HasSeenKeyVoxVibesIntro"
        static let hasCompletedFirstDictation = "KeyVox.App.HasCompletedFirstDictation"
        static let hasSkippedFirstDictation = "KeyVox.App.HasSkippedFirstDictation"
    }

    enum iCloud {
        static let dictionaryLastModifiedAt = "KeyVox.iCloud.DictionaryLastModifiedAt"
        static let triggerBindingLastModifiedAt = "KeyVox.iCloud.TriggerBindingLastModifiedAt"
        static let autoParagraphsLastModifiedAt = "KeyVox.iCloud.AutoParagraphsLastModifiedAt"
        static let listFormattingLastModifiedAt = "KeyVox.iCloud.ListFormattingLastModifiedAt"
    }
}
