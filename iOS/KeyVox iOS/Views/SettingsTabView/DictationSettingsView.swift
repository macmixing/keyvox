import SwiftUI

/// KeyVox's dictation settings, opened from the Dictation row in Settings: the session card,
/// the dictation model card, then the microphone preference.
struct DictationSettingsView: View {
    @Environment(\.appHaptics) var appHaptics
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject var dictationShortcutSetupIntroController: DictationShortcutSetupIntroController
    @EnvironmentObject private var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @EnvironmentObject private var keyVoxVibesIntroController: KeyVoxVibesIntroController
    @Binding var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @Binding var pendingDownloadConfirmation: PendingDownloadConfirmation?
    /// Set when another part of the app asks for the dictation model card to open.
    let modelSectionExpansionRequestID: UUID?
    @State var isModelSectionExpanded = false
    @State var modelExpandedContentHeight: CGFloat = 0
    @State var isDictationShortcutSetupPresented = false
    @State var isLanguagePickerPresented = false
    @State private var handledModelSectionExpansionRequestID: UUID?
    @StateObject var downloadNetworkMonitor = OnboardingDownloadNetworkMonitor()

    var body: some View {
        ScrollViewReader { scrollProxy in
            AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
                VStack(alignment: .leading, spacing: 16) {
                    sessionSection
                    activeModelSection
                    audioSection
                }
            }
            .onChange(of: modelSectionExpansionRequestID) { _, requestID in
                handleModelSectionExpansionRequest(requestID, scrollProxy: scrollProxy)
            }
            .onAppear {
                handleModelSectionExpansionRequest(modelSectionExpansionRequestID, scrollProxy: scrollProxy)
            }
        }
        .navigationTitle(DictationSettingsCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isDictationShortcutSetupPresented) {
            DictationShortcutSetupBrowsingView(mode: .settingsReference) {
                isDictationShortcutSetupPresented = false
            }
        }
        .fullScreenCover(isPresented: $isLanguagePickerPresented) {
            OnboardingLanguageScreen(
                presentationContext: .settings {
                    isLanguagePickerPresented = false
                }
            )
        }
        .blocksAppReviewRequest(isDictationShortcutSetupPresented || isLanguagePickerPresented)
        .onChange(of: isDictationShortcutSetupPresented) { _, isPresented in
            guard isPresented else { return }
            deferAutomaticFeatureIntroductions()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, isDictationShortcutSetupPresented else { return }
            deferAutomaticFeatureIntroductions()
        }
    }

    private func deferAutomaticFeatureIntroductions() {
        keyVoxVibesIntroController.markDeferredUntilNextEligibleLaunch()
        keyVoxVibesIntroController.cancelPendingPresentation()
        keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
        keyVoxSpeakIntroController.cancelPendingPresentation()
    }

    private func handleModelSectionExpansionRequest(_ requestID: UUID?, scrollProxy: ScrollViewProxy) {
        guard let requestID,
              handledModelSectionExpansionRequestID != requestID else {
            return
        }

        handledModelSectionExpansionRequestID = requestID

        withAnimation(SettingsTabView.sectionExpansionAnimation) {
            isModelSectionExpanded = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(SettingsTabView.sectionExpansionAnimation) {
                scrollProxy.scrollTo(DictationSettingsScrollTarget.dictationModel, anchor: .top)
            }
        }
    }
}

enum DictationSettingsScrollTarget {
    case dictationModel
}
