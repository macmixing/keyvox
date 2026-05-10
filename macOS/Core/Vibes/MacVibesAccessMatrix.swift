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
