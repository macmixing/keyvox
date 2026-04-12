import Testing
@testable import KeyVox_iOS

struct KeyVoxSpeakFlowRulesTests {
    @Test func introFlowKeepsScenesABCWhenSetupMustStillBeShown() {
        let scenes = KeyVoxSpeakFlowRules.displayedScenes(
            for: .intro(
                presentation: .full,
                onTryNow: {},
                onDismiss: {}
            ),
            isReadyForSelectedVoice: false
        )

        #expect(scenes == [.a, .b, .c])
    }

    @Test func introFlowDropsSceneCWhenPresentationHidesSetupAfterReadiness() {
        let presentation = KeyVoxSpeakSheetView.IntroPresentation(
            displayedScenes: [.a, .b, .c],
            initialScene: .a,
            sceneCTitleOverride: "One Tap Away",
            hidesSetupSceneWhenReady: true
        )

        let scenes = KeyVoxSpeakFlowRules.displayedScenes(
            for: .intro(
                presentation: presentation,
                onTryNow: {},
                onDismiss: {}
            ),
            isReadyForSelectedVoice: true
        )

        #expect(scenes == [.a, .b])
    }

    @Test func unlockFlowShowsSetupSceneWhenSelectedVoiceIsNotReady() {
        let scenes = KeyVoxSpeakFlowRules.displayedScenes(
            for: .unlock(onDismiss: {}),
            isReadyForSelectedVoice: false
        )

        #expect(scenes == [.unlock, .b, .c])
    }

    @Test func unlockFlowSkipsSetupSceneWhenSelectedVoiceIsReady() {
        let scenes = KeyVoxSpeakFlowRules.displayedScenes(
            for: .unlock(onDismiss: {}),
            isReadyForSelectedVoice: true
        )

        #expect(scenes == [.unlock, .b])
    }

    @Test func introFlowReselectsSceneBWhenSceneCDisappears() {
        let presentation = KeyVoxSpeakSheetView.IntroPresentation(
            displayedScenes: [.b, .c],
            initialScene: .b,
            sceneCTitleOverride: "One Tap Away",
            hidesSetupSceneWhenReady: true
        )

        let scene = KeyVoxSpeakFlowRules.syncedSelectedScene(
            currentScene: .c,
            displayedScenes: [.b],
            mode: .intro(
                presentation: presentation,
                onTryNow: {},
                onDismiss: {}
            )
        )

        #expect(scene == .b)
    }

    @Test func unlockFlowReselectsSceneBWhenSetupSceneDisappears() {
        let scene = KeyVoxSpeakFlowRules.syncedSelectedScene(
            currentScene: .c,
            displayedScenes: [.unlock, .b],
            mode: .unlock(onDismiss: {})
        )

        #expect(scene == .b)
    }

    @Test func questionMarkFlowShowsFullIntroBeforeAssetsOrUsage() {
        let presentation = KeyVoxSpeakFlowRules.helpPresentation(
            hasInstalledSpeakAssets: false,
            hasUsedKeyVoxSpeak: false
        )

        #expect(presentation.displayedScenes == [.a, .b, .c])
        #expect(presentation.initialScene == .a)
        #expect(presentation.sceneCTitleOverride == nil)
        #expect(presentation.hidesSetupSceneWhenReady == false)
    }

    @Test func questionMarkFlowStartsAtSceneAWhenAssetsAreReadyButFeatureIsUnused() {
        let presentation = KeyVoxSpeakFlowRules.helpPresentation(
            hasInstalledSpeakAssets: true,
            hasUsedKeyVoxSpeak: false
        )

        #expect(presentation.displayedScenes == [.a, .b])
        #expect(presentation.initialScene == .a)
        #expect(presentation.sceneCTitleOverride == nil)
        #expect(presentation.hidesSetupSceneWhenReady == false)
    }

    @Test func questionMarkFlowStartsAtSceneBWhenAssetsAreReadyAndFeatureWasUsed() {
        let presentation = KeyVoxSpeakFlowRules.helpPresentation(
            hasInstalledSpeakAssets: true,
            hasUsedKeyVoxSpeak: true
        )

        #expect(presentation.displayedScenes == [.b])
        #expect(presentation.initialScene == .b)
        #expect(presentation.sceneCTitleOverride == nil)
        #expect(presentation.hidesSetupSceneWhenReady == false)
    }

    @Test func questionMarkFlowKeepsSetupBranchForUsedFeatureWithoutInstalledAssets() {
        let presentation = KeyVoxSpeakFlowRules.helpPresentation(
            hasInstalledSpeakAssets: false,
            hasUsedKeyVoxSpeak: true
        )

        #expect(presentation.displayedScenes == [.b, .c])
        #expect(presentation.initialScene == .b)
        #expect(presentation.sceneCTitleOverride == "One Tap Away")
        #expect(presentation.hidesSetupSceneWhenReady)
    }
}
