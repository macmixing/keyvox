import Foundation

enum KeyVoxSpeakFlowRules {
    static func displayedScenes(
        for mode: KeyVoxSpeakSheetView.Mode,
        isReadyForSelectedVoice: Bool
    ) -> [KeyVoxSpeakSheetView.Scene] {
        switch mode {
        case .intro(let presentation, _, _):
            if presentation.hidesSetupSceneWhenReady && isReadyForSelectedVoice {
                return presentation.displayedScenes.filter { $0 != .c }
            }

            return presentation.displayedScenes
        case .unlock:
            if isReadyForSelectedVoice {
                return [.unlock, .b]
            }

            return [.unlock, .b, .c]
        }
    }

    static func syncedSelectedScene(
        currentScene: KeyVoxSpeakSheetView.Scene,
        displayedScenes: [KeyVoxSpeakSheetView.Scene],
        mode: KeyVoxSpeakSheetView.Mode
    ) -> KeyVoxSpeakSheetView.Scene {
        guard displayedScenes.contains(currentScene) == false else {
            return currentScene
        }

        switch mode {
        case .intro(let presentation, _, _):
            if presentation.hidesSetupSceneWhenReady, displayedScenes.contains(.b) {
                return .b
            }

            return displayedScenes.first ?? presentation.initialScene
        case .unlock:
            if displayedScenes.contains(.b) {
                return .b
            }

            return displayedScenes.first ?? .unlock
        }
    }

    static func helpPresentation(
        hasInstalledSpeakAssets: Bool,
        hasUsedKeyVoxSpeak: Bool
    ) -> KeyVoxSpeakSheetView.IntroPresentation {
        if hasInstalledSpeakAssets {
            if hasUsedKeyVoxSpeak {
                return .init(
                    displayedScenes: [.b],
                    initialScene: .b,
                    sceneCTitleOverride: nil,
                    hidesSetupSceneWhenReady: false
                )
            }

            return .init(
                displayedScenes: [.a, .b],
                initialScene: .a,
                sceneCTitleOverride: nil,
                hidesSetupSceneWhenReady: false
            )
        }

        if hasUsedKeyVoxSpeak {
            return .init(
                displayedScenes: [.b, .c],
                initialScene: .b,
                sceneCTitleOverride: "One Tap Away",
                hidesSetupSceneWhenReady: true
            )
        }

        return .full
    }
}
