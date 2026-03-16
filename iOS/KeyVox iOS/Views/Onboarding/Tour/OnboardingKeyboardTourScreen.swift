import Combine
import SwiftUI

struct OnboardingKeyboardTourScreen: View {
    private enum Metrics {
        static let inputBarHeight: CGFloat = 44
        static let inputBarBottomSpacing: CGFloat = 16
        static let sceneBottomSpacing: CGFloat = 92
    }

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var onboardingStore: iOSOnboardingStore
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager
    @State private var text = ""
    @State private var tourState = iOSOnboardingKeyboardTourState()
    @StateObject private var keyboardObserver = KeyboardObserver()
    @StateObject private var keyboardAccessProbe: iOSOnboardingKeyboardAccessProbe

    @MainActor
    init(keyboardAccessProbe: iOSOnboardingKeyboardAccessProbe? = nil) {
        let resolvedKeyboardAccessProbe = keyboardAccessProbe ?? iOSOnboardingKeyboardAccessProbe()
        _keyboardAccessProbe = StateObject(wrappedValue: resolvedKeyboardAccessProbe)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                iOSAppTheme.screenBackground
                    .ignoresSafeArea()

                sceneContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, iOSAppTheme.screenPadding)
                    .padding(.bottom, sceneBottomPadding(for: geometry))

                inputBar
                    .padding(.horizontal, iOSAppTheme.screenPadding)
                    .padding(.bottom, bottomPadding(for: geometry))
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()

                    Button("Finish") {
                        onboardingStore.completeKeyboardTour()
                    }
                    .tint(iOSAppTheme.accent)
                    .disabled(!tourState.canFinish)
                }
                .padding(.horizontal, iOSAppTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(iOSAppTheme.screenBackground.opacity(0.98))
            }
        }
        .task {
            tourState = iOSOnboardingKeyboardTourState()
            keyboardAccessProbe.refresh()
            syncKeyboardPresentationState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            keyboardAccessProbe.refresh()
            syncKeyboardPresentationState()
        }
        .onChange(of: keyboardObserver.keyboardHeight, initial: false) { _, newHeight in
            guard newHeight > 0 else { return }
            refreshAfterKeyboardPresentation()
        }
        .onReceive(transcriptionManager.$lastTranscriptionText.dropFirst()) { latestTranscription in
            handleLatestTranscription(latestTranscription)
        }
    }

    private var sceneContent: some View {
        Group {
            switch tourState.scene {
            case .a:
                OnboardingKeyboardTourSceneAView()
            case .b:
                OnboardingKeyboardTourSceneBView()
            case .c:
                OnboardingKeyboardTourSceneCView()
            }
        }
    }

    private var inputBar: some View {
        iOSAppCard {
            AutoFocusTextField(
                text: $text,
                placeholder: "",
                onSubmit: {}
            )
            .frame(height: 44)
        }
    }

    private func bottomPadding(for geometry: GeometryProxy) -> CGFloat {
        let keyboardInset = max(0, keyboardObserver.keyboardHeight - geometry.safeAreaInsets.bottom)
        return max(Metrics.inputBarBottomSpacing, keyboardInset)
    }

    private func sceneBottomPadding(for geometry: GeometryProxy) -> CGFloat {
        bottomPadding(for: geometry) + Metrics.inputBarHeight + Metrics.sceneBottomSpacing
    }

    private func refreshAfterKeyboardPresentation() {
        keyboardAccessProbe.refresh()
        syncKeyboardPresentationState()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            keyboardAccessProbe.refresh()
            syncKeyboardPresentationState()
        }
    }

    private func syncKeyboardPresentationState() {
        guard keyboardAccessProbe.hasShownKeyVoxKeyboard else { return }
        tourState.hasShownKeyVoxKeyboard = true
    }

    private func handleLatestTranscription(_ latestTranscription: String?) {
        guard scenePhase == .active,
              tourState.hasShownKeyVoxKeyboard,
              let latestTranscription,
              !latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        tourState.hasCompletedFirstTourTranscription = true
    }
}
