import Foundation
import KeyVoxStyleRewrite

struct MacVibesAccessMatrix: Equatable {
    enum ModelState: Equatable {
        case notInstalled
        case downloading(progress: Double)
        case installing(progress: Double)
        case failed(message: String)
        case ready
    }

    enum MainCardContent: Equatable {
        case downloadRequired
        case downloading
        case installing
        case installFailed
        case selectedVibe(StyleRewriteStyle)
    }

    enum CardControl: Equatable {
        case download
        case repair
        case progress
        case change
    }

    enum CardAction: Equatable {
        case downloadModel
        case repairModel
        case none
        case openVibeSelector
    }

    let mainCardContent: MainCardContent
    let cardControl: CardControl
    let cardAction: CardAction
    let progress: Double?
    let errorMessage: String?

    var showsVibeSelector: Bool {
        cardControl == .change
    }

    var displayedSelectedVibe: StyleRewriteStyle {
        if case .selectedVibe(let style) = mainCardContent {
            return style
        }

        return .none
    }

    var statusText: String {
        switch mainCardContent {
        case .downloadRequired:
            return MacVibesSettingsCopy.downloadRequiredStatus
        case .downloading:
            return MacVibesSettingsCopy.downloadingStatus
        case .installing:
            return MacVibesSettingsCopy.installingStatus
        case .installFailed:
            return MacVibesSettingsCopy.installFailedStatus
        case .selectedVibe:
            return MacVibesSettingsCopy.readyStatus
        }
    }

    static func resolve(
        modelState: ModelState,
        selectedVibe: StyleRewriteStyle
    ) -> MacVibesAccessMatrix {
        switch modelState {
        case .notInstalled:
            return MacVibesAccessMatrix(
                mainCardContent: .downloadRequired,
                cardControl: .download,
                cardAction: .downloadModel,
                progress: nil,
                errorMessage: nil
            )
        case .downloading(let progress):
            return MacVibesAccessMatrix(
                mainCardContent: .downloading,
                cardControl: .progress,
                cardAction: .none,
                progress: progress,
                errorMessage: nil
            )
        case .installing(let progress):
            return MacVibesAccessMatrix(
                mainCardContent: .installing,
                cardControl: .progress,
                cardAction: .none,
                progress: progress,
                errorMessage: nil
            )
        case .failed(let message):
            return MacVibesAccessMatrix(
                mainCardContent: .installFailed,
                cardControl: .repair,
                cardAction: .repairModel,
                progress: nil,
                errorMessage: message
            )
        case .ready:
            return MacVibesAccessMatrix(
                mainCardContent: .selectedVibe(selectedVibe),
                cardControl: .change,
                cardAction: .openVibeSelector,
                progress: nil,
                errorMessage: nil
            )
        }
    }

    static func modelState(from installState: MacLocalRewriteModelInstallState) -> ModelState {
        switch installState {
        case .notInstalled:
            return .notInstalled
        case .downloading(let progress):
            return .downloading(progress: progress)
        case .installing(let progress):
            return .installing(progress: progress)
        case .ready:
            return .ready
        case .failed(let message):
            return .failed(message: message)
        }
    }
}

enum MacVibesSettingsCopy {
    static let cardTitle = "KeyVox Vibes"
    static let cardSubtitle = "On-device, reversible writing styles."
    static let aiCardTitle = "KeyVox Vibes AI"
    static let aiReadyStatus = "KeyVox Vibes AI is installed and ready."
    static let aiDownloadRequiredStatus = "Install Vibes AI first (~491 MB), then you can use KeyVox Vibes."
    static let pickerAccessibilityLabel = "KeyVox Vibes"
    static let downloadRequiredStatus = "Install Vibes AI first (~491 MB), then you can use KeyVox Vibes."
    static let downloadingStatus = "Downloading KeyVox Vibes AI."
    static let installingStatus = "Installing KeyVox Vibes AI."
    static let installFailedStatus = "Install failed."
    static let readyStatus = "KeyVox Vibes AI is installed and ready."
    static let downloadingBadge = "Downloading"
    static let installingBadge = "Installing"
    static let downloadAction = "Download"
    static let repairAction = "Repair"
    static let deleteAction = "Delete"
    static let triggerTip = "Tap the trigger key to apply / undo the current Vibe. Double-tap to cycle Vibes."
    static let deleteConfirmationTitle = "Delete KeyVox Vibes AI?"
    static let deleteConfirmationMessage = "KeyVox Vibes AI will be removed from this Mac."
    static let downloadFailed = "Vibes model download failed. Check your network/storage and retry."
    static let downloadCancelled = "Vibes model download was cancelled."
    static let integrityCheckFailed = "Downloaded Vibes model did not match the expected SHA-256."
}
