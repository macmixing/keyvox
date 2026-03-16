import Foundation

struct iOSOnboardingKeyboardTourState: Equatable {
    enum Scene: Equatable {
        case a
        case b
        case c
    }

    var hasShownKeyVoxKeyboard = false
    var hasCompletedFirstTourTranscription = false

    var scene: Scene {
        if hasCompletedFirstTourTranscription {
            return .c
        }

        if hasShownKeyVoxKeyboard {
            return .b
        }

        return .a
    }

    var canFinish: Bool {
        hasShownKeyVoxKeyboard && hasCompletedFirstTourTranscription
    }
}
