import KeyVoxStyleRewrite

struct KeyVoxVibesAccessMatrix: Equatable {
    enum AccessState: Equatable {
        case noTrialStartedNotUnlocked
        case trialActive
        case trialExpiredNotUnlocked
        case unlocked
    }

    enum ModelState: Equatable {
        case missing
        case installed
    }

    enum MainCardContent: Equatable {
        case trialOffer
        case downloadRequired
        case selectedVibe(StyleRewriteStyle)
        case unlockOffer
    }

    enum CardControl: Equatable {
        case tryNow
        case download
        case change
        case unlock
    }

    enum CardAction: Equatable {
        case openIntroFlow
        case openSceneCRecovery
        case openVibeSelector
        case openUnlockScene
        case openUnlockFlow
        case openUnlockedModelRecovery
    }

    enum DestinationStart: Equatable {
        case sceneA
        case sceneC
        case vibeSelector
        case unlockScene
        case featureUnlockFlow
    }

    enum DynamicText: Equatable {
        case none
        case mainCardTrialRemaining
        case sceneCTrialRemaining
        case unlockSubtitle
    }

    enum DestinationCTA: Equatable {
        case introModelMissing
        case tryNow
        case none
        case unlockPurchase
        case continueWhenVibesAIReady
    }

    let mainCardContent: MainCardContent
    let cardControl: CardControl
    let cardAction: CardAction
    let destinationStart: DestinationStart
    let dynamicText: DynamicText
    let destinationCTA: DestinationCTA

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
        accessState: AccessState,
        modelState: ModelState,
        selectedVibe: StyleRewriteStyle
    ) -> KeyVoxVibesAccessMatrix {
        switch (accessState, modelState) {
        case (.noTrialStartedNotUnlocked, .missing):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .trialOffer,
                cardControl: .tryNow,
                cardAction: .openIntroFlow,
                destinationStart: .sceneA,
                dynamicText: .none,
                destinationCTA: .introModelMissing
            )
        case (.noTrialStartedNotUnlocked, .installed):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .trialOffer,
                cardControl: .tryNow,
                cardAction: .openIntroFlow,
                destinationStart: .sceneA,
                dynamicText: .none,
                destinationCTA: .tryNow
            )
        case (.trialActive, .missing):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .downloadRequired,
                cardControl: .download,
                cardAction: .openSceneCRecovery,
                destinationStart: .sceneC,
                dynamicText: .sceneCTrialRemaining,
                destinationCTA: .introModelMissing
            )
        case (.trialActive, .installed):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .selectedVibe(selectedVibe),
                cardControl: .change,
                cardAction: .openVibeSelector,
                destinationStart: .vibeSelector,
                dynamicText: .mainCardTrialRemaining,
                destinationCTA: .none
            )
        case (.trialExpiredNotUnlocked, .missing):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .unlockOffer,
                cardControl: .unlock,
                cardAction: .openUnlockScene,
                destinationStart: .unlockScene,
                dynamicText: .unlockSubtitle,
                destinationCTA: .unlockPurchase
            )
        case (.trialExpiredNotUnlocked, .installed):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .unlockOffer,
                cardControl: .unlock,
                cardAction: .openUnlockFlow,
                destinationStart: .featureUnlockFlow,
                dynamicText: .unlockSubtitle,
                destinationCTA: .unlockPurchase
            )
        case (.unlocked, .missing):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .downloadRequired,
                cardControl: .download,
                cardAction: .openUnlockedModelRecovery,
                destinationStart: .unlockScene,
                dynamicText: .unlockSubtitle,
                destinationCTA: .continueWhenVibesAIReady
            )
        case (.unlocked, .installed):
            return KeyVoxVibesAccessMatrix(
                mainCardContent: .selectedVibe(selectedVibe),
                cardControl: .change,
                cardAction: .openVibeSelector,
                destinationStart: .vibeSelector,
                dynamicText: .none,
                destinationCTA: .none
            )
        }
    }

    static func accessState(
        isVibesUnlocked: Bool,
        hasTrialStarted: Bool,
        isTrialActive: Bool
    ) -> AccessState {
        if isVibesUnlocked {
            return .unlocked
        }

        if isTrialActive {
            return .trialActive
        }

        if hasTrialStarted {
            return .trialExpiredNotUnlocked
        }

        return .noTrialStartedNotUnlocked
    }

    static func modelState(isVibesAIInstalled: Bool) -> ModelState {
        isVibesAIInstalled ? .installed : .missing
    }
}
